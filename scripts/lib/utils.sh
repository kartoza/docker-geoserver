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
  if [[ "$(id -u)" -eq 0 ]]; then
    USER_ID="${GEOSERVER_UID:-2000}"
    GROUP_ID="${GEOSERVER_GID:-2000}"
    USER_NAME="${GEOSERVER_USER:-${USER:-geoserveruser}}"
    GEO_GROUP_NAME="${GROUP_NAME:-geoserverusers}"
  else
    USER_ID="$(id -u)"
    GROUP_ID="$(id -g)"
    USER_NAME="$(id -un 2>/dev/null || printf '%s' "${USER_ID}")"
    GEO_GROUP_NAME="$(id -gn 2>/dev/null || printf '%s' "${GROUP_ID}")"
  fi

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

  # Platforms such as OpenShift assign an arbitrary UID at runtime. In that
  # case the image cannot (and does not need to) modify /etc/passwd or groups.
  [[ "$(id -u)" -ne 0 ]] && return 0

  ensure_group_exists
  ensure_user_exists
}

validate_runtime_write_access() {
  [[ "$(id -u)" -eq 0 ]] && return 0

  local path
  local runtime_paths=(
    "${GEOSERVER_DATA_DIR}"
    "${GEOWEBCACHE_CACHE_DIR}"
    "${GEOSERVER_HOME}"
    "${CATALINA_HOME}/conf"
    "${CATALINA_HOME}/logs"
    "${CATALINA_HOME}/temp"
    "${CATALINA_HOME}/webapps"
    "${CATALINA_HOME}/work"
    "${CERT_DIR}"
    "${EXTRA_CONFIG_DIR}"
    "${FONTS_DIR}"
  )

  for path in "${runtime_paths[@]}"; do
    if [[ ! -w "${path}" ]]; then
      echo -e "\e[31m [ERROR] Arbitrary UID ${USER_ID}:${GROUP_ID} cannot write to ${path}. Ensure the mounted path is group-writable. \033[0m" >&2
      return 1
    fi
  done
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
  local tmp_list="$2"

  [[ -e "$target" ]] || return 0

  local owner group start end elapsed
  owner=$(stat -c '%U' "$target")
  group=$(stat -c '%G' "$target")

  # Fix top-level directory if needed
  if [[ "$owner" != "$USER_NAME" || "$group" != "$GEO_GROUP_NAME" ]]; then
    echo -e "\e[32m [Entrypoint] Fixing ownership for:\033[0m \e[1;31m $target \033[0m"
    chown "$USER_NAME:$GEO_GROUP_NAME" "$target"
  fi

  # If directory, collect mismatches first
  [[ -d "$target" ]] || return 0

  find "$target" -mindepth 1 \
    \( ! -user "$USER_NAME" -o ! -group "$GEO_GROUP_NAME" \) \
    > "$tmp_list"

  # Iterate mismatches to change permissions
  while IFS= read -r file; do
    current_user=$(stat -c '%U' "$file")
    current_group=$(stat -c '%G' "$file")

    if [[ "$current_user" != "$USER_NAME" || "$current_group" != "$GEO_GROUP_NAME" ]]; then
      start=$(date +%s)

      chown "$USER_NAME:$GEO_GROUP_NAME" "$file"

      end=$(date +%s)
      elapsed=$((end - start))

      if [[ ${VERBOSE_LOGGING} =~ [Tt][Rr][Uu][Ee] ]]; then
        echo -e "\e[32m [Entrypoint] Completed:\033[0m \e[1;31m ${file} \033[0m \e[32m( changed in ${elapsed}s)\033[0m"
      fi
    fi
  done < "$tmp_list"

  rm -f "$tmp_list"
}

geo_data_file_perms() {
  local target_dir="$1"
  [[ -d "$target_dir" ]] || return 1

  fix_path_ownership "$target_dir" "/tmp/data_dir_chown_list.txt"
}

fix_permissions() {

  change_owner_if_needed() {
    fix_path_ownership "$1" "/tmp/fix_ownership_list.txt"
  }

  if [[ "$(id -u)" -ne 0 ]]; then
    return 0
  fi

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
      change_owner_if_needed "$directory"
    done

    change_owner_if_needed "${CLUSTER_CONFIG_DIR}"
    change_owner_if_needed "${GEOSERVER_DATA_DIR}/logging.xml"
    change_owner_if_needed "${GEOSERVER_DATA_DIR}/jdbcconfig"
    change_owner_if_needed "${GEOSERVER_DATA_DIR}/jdbcstore"
    change_owner_if_needed "${GEOSERVER_LOG_DIR}"
    change_owner_if_needed "${GEOSERVER_DATA_DIR}/cluster"
  fi

  chmod o+rw "${CERT_DIR}"

  echo -e "\e[32m [Entrypoint] Fixing Permissions for:\033[0m \e[1;31m ${GEOSERVER_DATA_DIR} && ${GEOWEBCACHE_CACHE_DIR}\033[0m"

  geo_data_file_perms "${GEOWEBCACHE_CACHE_DIR}"
  geo_data_file_perms "${GEOSERVER_DATA_DIR}"

  find "${CATALINA_HOME}/conf/" -type f -exec chmod 400 {} \;

  if [[ ${SAMPLE_DATA} =~ [Tt][Rr][Uu][Ee] ]]; then
    change_owner_if_needed "${GEOSERVER_DATA_DIR}"
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
