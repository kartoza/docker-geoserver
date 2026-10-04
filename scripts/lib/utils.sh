#!/usr/bin/env bash

############################################
# 1. BASIC UTILITIES
############################################

generate_random_string() {
  local length="$1"
  local file="${EXTRA_CONFIG_DIR}/.pass_${length}.txt"

  [[ -f "${file}" ]] || tr -dc '[:alnum:]' </dev/urandom | head -c "${length}" > "${file}"
  RAND="$(<"${file}")"
  export RAND
}




create_dir() {
  local DATA_PATH="$1"

  if [[ -z "${DATA_PATH}" ]]; then
    echo -e "\e[31m [ERROR] create_dir: No path provided \033[0m" >&2
    return 1
  fi

  if [[ ! -d "${DATA_PATH}" ]]; then
    if ! mkdir -p "${DATA_PATH}"; then
      echo -e "\e[31m [ERROR] Failed to create directory: ${DATA_PATH} \033[0m" >&2
      return 1
    fi
  fi
}



delete_file() {
  [[ -f "$1" ]] && rm "$1"
}

delete_folder() {
  [[ -d "$1" ]] && rm -r "$1"
}


clean_up_vars() {
  if [[ -f /tmp/set_vars.txt ]]; then
    for vars in $(cat /tmp/set_vars.txt); do unset "$vars"; done
    rm /tmp/set_vars.txt
  fi
}


############################################
# 2. RUNTIME USER & GROUP MANAGEMENT
############################################

init_runtime_user_vars() {
  USER_ID="${GEOSERVER_UID:-2000}"
  GROUP_ID="${GEOSERVER_GID:-2000}"
  USER_NAME="${USER:-geoserveruser}"
  GEO_GROUP_NAME="${GROUP_NAME:-geoserverusers}"

  export USER_ID GROUP_ID USER_NAME GEO_GROUP_NAME
}

ensure_group_exists() {
  if ! getent group "${GEO_GROUP_NAME}" >/dev/null; then
    groupadd -r "${GEO_GROUP_NAME}" -g "${GROUP_ID}"
  fi
}

ensure_user_exists() {
  if ! id -u "${USER_NAME}" >/dev/null 2>&1; then
    useradd \
      -l \
      -m \
      -d "/home/${USER_NAME}" \
      -u "${USER_ID}" \
      --gid "${GROUP_ID}" \
      -s /bin/bash \
      -G "${GEO_GROUP_NAME}" \
      "${USER_NAME}"
  fi
}

setup_geoserver_users() {
  init_runtime_user_vars
  ensure_group_exists
  ensure_user_exists
}

############################################
# 3. GEOSERVER SECURITY HELPERS
############################################

make_hash() {
  local NEW_PASSWORD="$1"
  local GEO_INSTALL_PATH="$2"
  local ALGO_TYPE="$3"

  local HASH
  HASH=$(java -classpath "$(find "${GEO_INSTALL_PATH}" -regex '.*jasypt-[0-9]\.[0-9]\.[0-9].*jar')" \
    org.jasypt.intf.cli.JasyptStringDigestCLI digest.sh \
    algorithm="${ALGO_TYPE}" saltSizeBytes=16 iterations=100000 input="${NEW_PASSWORD}" verbose=0 \
    2>/dev/null \
    | grep -Eoi '^[A-Za-z0-9+/=]+$' \
    | head -1)

  echo "digest1:${HASH}"
}



############################################
# 4. GEOWEBCACHE & FILE PERMISSIONS
############################################

fix_path_ownership() {
  local target="$1"

  [[ -e "$target" ]] || return 0

  local owner group
  owner=$(stat -c '%U' "$target")
  group=$(stat -c '%G' "$target")

  # Fix top-level directory if needed
  if [[ "$owner" != "$USER_NAME" || "$group" != "$GEO_GROUP_NAME" ]]; then
    echo -e "\e[32m [Entrypoint] Fixing ownership for:\033[0m \e[1;31m $target \033[0m"
    chown "$USER_NAME:$GEO_GROUP_NAME" "$target"
  fi

  [[ -d "$target" ]] || return 0

  if [[ ${VERBOSE_LOGGING} =~ [Tt][Rr][Uu][Ee] ]]; then
    find "$target" -mindepth 1 \
      \( ! -user "$USER_NAME" -o ! -group "$GEO_GROUP_NAME" \) \
      -exec sh -c '
        for file do
          start=$(date +%s)
          chown "$USER_NAME:$GEO_GROUP_NAME" "$file"
          end=$(date +%s)
          elapsed=$((end - start))
          echo -e "\e[32m [Entrypoint] Completed:\033[0m \e[1;31m ${file} \033[0m \e[32m( changed in ${elapsed}s)\033[0m"
        done
      ' sh {} +
  else
    find "$target" -mindepth 1 \
      \( ! -user "$USER_NAME" -o ! -group "$GEO_GROUP_NAME" \) \
      -exec chown "$USER_NAME:$GEO_GROUP_NAME" {} +
  fi
}

gwc_file_perms() {
  GEO_USER_PERM=$(stat -c '%U' "${GEOSERVER_DATA_DIR}")
  GEO_GRP_PERM=$(stat -c '%G' "${GEOSERVER_DATA_DIR}")
  GWC_USER_PERM=$(stat -c '%U' "${GEOWEBCACHE_CACHE_DIR}")
  GWC_GRP_PERM=$(stat -c '%G' "${GEOWEBCACHE_CACHE_DIR}")
  case "${GEOWEBCACHE_CACHE_DIR}" in ${GEOSERVER_DATA_DIR}/*)
    echo -e " \e[32m [Entrypoint] \033[0m \e[1;31m ${GEOWEBCACHE_CACHE_DIR} \033[0m \e[32m is nested in \033[0m \e[1;31m ${GEOSERVER_DATA_DIR} \033[0m"
    if [[ ${CHOWN_DATA_DIR} =~ [Tt][Rr][Uu][Ee] ]];then
      if [[ ${GEO_USER_PERM} != "${USER_NAME}" ]] &&  [[ ${GEO_GRP_PERM} != "${GEO_GROUP_NAME}"  ]];then
        echo -e "\e[32m [Entrypoint] Changing folder permission for:\033[0m \e[1;31m ${GEOSERVER_DATA_DIR} \033[0m"
        chown -R "${USER_NAME}":"${GEO_GROUP_NAME}" "${GEOSERVER_DATA_DIR}"
      fi
    fi
    ;;
  *)
    echo -e "\e[1;31m ${GEOWEBCACHE_CACHE_DIR} \033[0m is not nested in \e[1;31m ${GEOSERVER_DATA_DIR} \033[0m"
    if [[ ${CHOWN_DATA_DIR} =~ [Tt][Rr][Uu][Ee] ]];then
      if [[ ${GEO_USER_PERM} != "${USER_NAME}" ]] &&  [[ ${GEO_GRP_PERM} != "${GEO_GROUP_NAME}"  ]];then
        echo -e "\e[32m [Entrypoint] Changing folder permission for:\033[0m \e[1;31m ${GEOSERVER_DATA_DIR} \033[0m"
        chown -R "${USER_NAME}":"${GEO_GROUP_NAME}" "${GEOSERVER_DATA_DIR}"
      fi
    fi
    if [[ ${CHOWN_GWC_DATA_DIR} =~ [Tt][Rr][Uu][Ee] ]];then
      if [[ ${GWC_USER_PERM} != "${USER_NAME}" ]] &&  [[ ${GWC_GRP_PERM} != "${GEO_GROUP_NAME}"  ]];then
        echo -e "\e[32m [Entrypoint] Changing folder permission for:\033[0m \e[1;31m ${GEOWEBCACHE_CACHE_DIR} \033[0m"
        chown -R "${USER_NAME}":"${GEO_GROUP_NAME}" "${GEOWEBCACHE_CACHE_DIR}"
      fi
    fi
   ;;
esac

}


fix_permissions() {

  if [[ ${RUN_AS_ROOT} =~ [Ff][Aa][Ll][Ss][Ee] ]]; then

    dir_ownership=(
      "${CATALINA_HOME}/bin"
      "${CATALINA_HOME}/conf"
      "/home/${USER_NAME}/"
      "${COMMUNITY_PLUGINS_DIR}"
      "${STABLE_PLUGINS_DIR}"
      "${REQUIRED_PLUGINS_DIR}"
      "${GEOSERVER_HOME}"
      "/usr/share/fonts/"
      "${FOOTPRINTS_DATA_DIR}"
      "${CERT_DIR}"
      "${FONTS_DIR}"
      "/scripts/"
      "${EXTRA_CONFIG_DIR}"
      "/docker-entrypoint-geoserver.d"
      "${MONITOR_AUDIT_PATH}"
    )

    for directory in "${dir_ownership[@]}"; do
      fix_path_ownership "$directory"
    done

    fix_path_ownership "${CLUSTER_CONFIG_DIR}"
    fix_path_ownership "${GEOSERVER_DATA_DIR}/logging.xml"
    fix_path_ownership "${GEOSERVER_DATA_DIR}/jdbcconfig"
    fix_path_ownership "${GEOSERVER_DATA_DIR}/jdbcstore"
    fix_path_ownership "${GEOSERVER_LOG_DIR}"
    fix_path_ownership "${GEOSERVER_DATA_DIR}/cluster"
  fi

  chmod o+rw "${CERT_DIR}"

  echo -e "\e[32m [Entrypoint] Fixing Permissions for:\033[0m \e[1;31m ${GEOSERVER_DATA_DIR} && ${GEOWEBCACHE_CACHE_DIR}\033[0m"

  gwc_file_perms

  find "${CATALINA_HOME}/conf/" -type f -exec chmod 400 {} \;

}


############################################
# 6. FONTS & NATIVE LIBRARIES
############################################

setup_google_fonts() {
  [[ -z "${GOOGLE_FONTS_NAMES}" ]] && return

  git clone --filter=blob:none --no-checkout https://github.com/google/fonts.git
  cd fonts || return
  git config core.sparsecheckout true

  for gfont in ${GOOGLE_FONTS_NAMES//,/ }; do
    grep -Fxq "$gfont" /build_data/google_fonts.txt &&
      echo "ofl/$gfont" >> .git/info/sparse-checkout
  done

  git checkout main

  for gfont in ${GOOGLE_FONTS_NAMES//,/ }; do
    grep -Fxq "$gfont" /build_data/google_fonts.txt &&
      cp -r "ofl/$gfont" /usr/share/fonts/truetype/
  done

  cd ..
  rm -rf fonts
}

install_fonts() {
  ls "${FONTS_DIR}"/*.ttf >/dev/null 2>&1 && cp -rf "${FONTS_DIR}"/*.ttf /usr/share/fonts/truetype/
  ls "${FONTS_DIR}"/*.otf >/dev/null 2>&1 && cp -rf "${FONTS_DIR}"/*.otf /usr/share/fonts/opentype/
  setup_google_fonts
}

install_sample_data(){
  if [[ ${SAMPLE_DATA} =~ [Tt][Rr][Uu][Ee] ]]; then
    cp -r "${CATALINA_HOME}"/data /tmp/
    fix_path_ownership /tmp/data
    cp -r /tmp/data/* "${GEOSERVER_DATA_DIR}"
    rm -rf /tmp/data
  fi
}



############################################
# 7. DATA & DIRECTORY LIFECYCLE
############################################

create_entrypoint_directories() {
  local dirs=(
    "${GEOSERVER_DATA_DIR}"
    "${CERT_DIR}"
    "${FOOTPRINTS_DATA_DIR}"
    "${FONTS_DIR}"
    "${GEOWEBCACHE_CACHE_DIR}"
    "${GEOSERVER_HOME}"
    "${EXTRA_CONFIG_DIR}"
    "${SCRIPTS_LOCKFILE_DIR}"
    "/docker-entrypoint-geoserver.d"
  )

  for d in "${dirs[@]}"; do
    create_dir "${d}"
  done
}

create_setup_directories() {
  local dirs=(
    ${resources_dir}/plugins/gdal
    /usr/share/fonts/opentype
    /tomcat_apps
    "${CATALINA_HOME}"/postgres_config
    "${STABLE_PLUGINS_DIR}"
    "${COMMUNITY_PLUGINS_DIR}"
    "${GEOSERVER_HOME}"
    "${FONTS_DIR}"
    "${REQUIRED_PLUGINS_DIR}"
  )

  for d in "${dirs[@]}"; do
    create_dir "${d}"
  done
}

cleanup_data_dir() {
  [[ "${RECREATE_DATADIR}" =~ [Tt][Rr][Uu][Ee] ]] &&
    rm -rf "${GEOSERVER_DATA_DIR:?}/"*
}

apply_overlays() {
  rm -f /tmp/resources/overlays/README.txt
  if ls /tmp/resources/overlays/* >/dev/null 2>&1; then
    cp -rf /tmp/resources/overlays/* /
  fi
}

cleanup_resources() {
  rm -rf /tmp/resources
  delete_file "${CATALINA_HOME}/conf/web.xml"
}

############################################
# 8. ENTRYPOINT & HOOKS
############################################

entry_point_script() {
  if find "/docker-entrypoint-geoserver.d" -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
    for f in /docker-entrypoint-geoserver.d/*; do
      case "$f" in
        *.sh) echo "$0: running $f"; . "$f" || true ;;
        *)    echo "$0: ignoring $f" ;;
      esac
      echo
    done
  fi
}

run_pre_start_hooks() {
  local hook="${SCRIPT_DIR}/start.sh"

  if [[ -x "${hook}" ]]; then
    log "Running pre-start hook"
    /bin/bash "${hook}"
  elif [[ -f "${hook}" ]]; then
    log_warn "start.sh not executable, running via bash"
    /bin/bash "${hook}"
  fi
}

run_update_password_hook() {
  local hook="${SCRIPT_DIR}/lib/update_passwords.sh"

  [[ -n "${EXISTING_DATA_DIR}" ]] && return

  if [[ -x "${hook}" ]]; then
    /bin/bash "${hook}"
  elif [[ -f "${hook}" ]]; then
    /bin/bash "${hook}"
  fi
}

