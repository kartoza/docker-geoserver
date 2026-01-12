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
  [[ -z "$1" ]] && return 1
  [[ -d "$1" ]] || mkdir -p "$1"
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

create_required_dirs() {
  local path=(
    "${resources_dir}/plugins/gdal"
    "/usr/share/fonts/opentype"
    "/tomcat_apps"
    "${CATALINA_HOME}/postgres_config"
    "${STABLE_PLUGINS_DIR}"
    "${COMMUNITY_PLUGINS_DIR}"
    "${GEOSERVER_HOME}"
    "${FONTS_DIR}"
    "${REQUIRED_PLUGINS_DIR}"
  )

  for dir in "${path[@]}"; do
    echo "Creating directory: $dir"
    create_dir "${dir}"
  done
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

setup_runtime_user() {
  init_runtime_user_vars
  ensure_group_exists
  ensure_user_exists
}

############################################
# 3. GEOSERVER INSTALL & SECURITY HELPERS
############################################

detect_install_dir() {
  [[ -f "${GEOSERVER_HOME}/start.jar" ]] && echo "${GEOSERVER_HOME}" || echo "${CATALINA_HOME}"
}

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

rename_context_root_if_needed() {
  if [[ "${GEOSERVER_CONTEXT_ROOT}" != "geoserver" ]]; then
    log "Changing context-root to ${GEOSERVER_CONTEXT_ROOT}"
    local install_dir
    install_dir="$(detect_install_dir)"

    if [[ -d "${install_dir}/webapps/geoserver" ]]; then
      mv "${install_dir}/webapps/geoserver" \
         "${install_dir}/webapps/${GEOSERVER_CONTEXT_ROOT}"
    else
      log_warn "Context already renamed or first-run skipped"
    fi
  fi
}

############################################
# 4. GEOWEBCACHE & FILE PERMISSIONS
############################################

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
  # Helper: change ownership if needed
  change_owner_if_needed() {
    local target="$1"
    if [[ -e "$target" ]]; then
      local owner group
      owner=$(stat -c '%U' "$target")
      group=$(stat -c '%G' "$target")
      if [[ "$owner" != "$USER_NAME" || "$group" != "$GEO_GROUP_NAME" ]]; then
        echo -e "\e[32m [Entrypoint] Changing folder permission for:\033[0m \e[1;31m $target \033[0m"
        chown -R "$USER_NAME":"$GEO_GROUP_NAME" "$target"
      fi
    fi
  }

  if [[ ${RUN_AS_ROOT} =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
    # Core directories to check
    dir_ownership=(
      "${CATALINA_HOME}"
      "/home/${USER_NAME}/"
      "${COMMUNITY_PLUGINS_DIR}"
      "${STABLE_PLUGINS_DIR}"
      "${REQUIRED_PLUGINS_DIR}"
      "${GEOSERVER_HOME}"
      "/usr/share/fonts/"
      "/tmp/"
      "${FOOTPRINTS_DATA_DIR}"
      "${CERT_DIR}"
      "${FONTS_DIR}"
      "/scripts/"
      "${EXTRA_CONFIG_DIR}"
      "/docker-entrypoint-geoserver.d"
      "${MONITOR_AUDIT_PATH}"
    )

    for directory in "${dir_ownership[@]}"; do
      change_owner_if_needed "$directory"
    done

    # Special cases
    change_owner_if_needed "${CLUSTER_CONFIG_DIR}"
    change_owner_if_needed "${GEOSERVER_DATA_DIR}/logging.xml"
    change_owner_if_needed "${GEOSERVER_DATA_DIR}/jdbcconfig"
    change_owner_if_needed "${GEOSERVER_DATA_DIR}/jdbcstore"
    change_owner_if_needed "${GEOSERVER_LOG_DIR}"
    change_owner_if_needed "${GEOSERVER_DATA_DIR}/cluster"
  fi

  # Permissions adjustments
  chmod o+rw "${CERT_DIR}"
  gwc_file_perms
  find "${CATALINA_HOME}/conf/" -type f -exec chmod 400 {} \;

  # Sample data ownership fix

  if [[ ${SAMPLE_DATA} =~ [Tt][Rr][Uu][Ee] ]]; then
      change_owner_if_needed "${GEOSERVER_DATA_DIR}"
  fi
}

############################################
# 5. S3 COMMUNITY EXTENSION
############################################

s3_config() {
  cat >"${GEOSERVER_DATA_DIR}/s3.properties" <<EOF
${S3_ALIAS}.s3.endpoint=${S3_SERVER_URL}
${S3_ALIAS}.s3.user=${S3_USERNAME}
${S3_ALIAS}.s3.password=${S3_PASSWORD}
EOF
}

setup_s3_extension() {
  export S3_SERVER_URL S3_USERNAME S3_PASSWORD S3_ALIAS

  if [[ -z "${S3_SERVER_URL}" || -z "${S3_USERNAME}" || -z "${S3_PASSWORD}" || -z "${S3_ALIAS}" ]]; then
    echo -e "\e[32m [Entrypoint] Missing S3 vars, skipping s3.properties \033[0m"
    return
  fi

  if [[ "${ADDITIONAL_JAVA_STARTUP_OPTIONS}" == *"-Ds3.properties.location"* ]]; then
    s3_config
  else
    echo -e "\e[32m [Entrypoint] -Ds3.properties.location not set, skipping S3 \033[0m"
  fi
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
    cp -r "${CATALINA_HOME}"/data/* "${GEOSERVER_DATA_DIR}"
  fi
}


install_libjpegturbo() {
  local arch
  arch=$(dpkg --print-architecture)
  local version="2.1.5.1"
  local deb="libjpeg-turbo-official_${version}_${arch}.deb"

  [[ -f "${resources_dir}/${deb}" ]] ||
    curl -vfLo "${resources_dir}/${deb}" \
      "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/${version}/${deb}"

  dpkg -i "${resources_dir}/${deb}"
}

install_plugin_dependency() {
  pushd "${STABLE_PLUGINS_DIR}" || exit
  install_libjpegturbo
}

############################################
# 7. DATA & DIRECTORY LIFECYCLE
############################################

create_required_directories() {
  local dirs=(
    "${GEOSERVER_DATA_DIR}"
    "${CERT_DIR}"
    "${FOOTPRINTS_DATA_DIR}"
    "${FONTS_DIR}"
    "${GEOWEBCACHE_CACHE_DIR}"
    "${GEOSERVER_HOME}"
    "${EXTRA_CONFIG_DIR}"
    "/docker-entrypoint-geoserver.d"
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
  pushd /scripts || exit
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
