#!/usr/bin/env bash

generate_random_string() {
  local length="$1"
  local file="${EXTRA_CONFIG_DIR}/.pass_${length}.txt"

  [[ -f "${file}" ]] || tr -dc '[:alnum:]' </dev/urandom | head -c "${length}" > "${file}"
  export RAND
  RAND="$(<"${file}")"
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



detect_install_dir() {
  [[ -f "${GEOSERVER_HOME}/start.jar" ]] && echo "${GEOSERVER_HOME}" || echo "${CATALINA_HOME}"
}


make_hash() {
    NEW_PASSWORD=$1
    GEO_INSTALL_PATH=$2
    ALGO_TYPE=$3

    HASH=$(java -classpath $(find "${GEO_INSTALL_PATH}" -regex ".*jasypt-[0-9]\.[0-9]\.[0-9].*jar") \
        org.jasypt.intf.cli.JasyptStringDigestCLI digest.sh \
        algorithm=$ALGO_TYPE saltSizeBytes=16 iterations=100000 input="$NEW_PASSWORD" verbose=0 \
        2>/dev/null \
        | grep -Eoi '^[A-Za-z0-9+/=]+$' \
        | head -1)

    echo "digest1:${HASH}"
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

entry_point_script() {
  if find "/docker-entrypoint-geoserver.d" -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
    for f in /docker-entrypoint-geoserver.d/*; do
      case "$f" in
        *.sh)
          echo "$0: running $f"
          . "$f" || true
          ;;
        *)
          echo "$0: ignoring $f"
          ;;
      esac
      echo
    done
  fi
}

s3_config() {
  cat >"${GEOSERVER_DATA_DIR}"/s3.properties <<EOF
${S3_ALIAS}.s3.endpoint=${S3_SERVER_URL}
${S3_ALIAS}.s3.user=${S3_USERNAME}
${S3_ALIAS}.s3.password=${S3_PASSWORD}
EOF

}


# Helper function to download extensions
download_extension() {
  local url="$1"
  local plugin="$2"
  local output_path="$3"

  curl --progress-bar -fLvo \
    "${output_path}/${plugin}.zip" \
    "${url}"
}

validate_geo_install() {
  DATA_PATH=$1
  # Check if geoserver is installed early so that we can fail early on
  if [[ $(ls -A "${DATA_PATH}")  ]]; then
     echo -e "\e[32m  GeoServer install dir exist proceed with install \033[0m"
  else
    echo -e "\e[32m  GeoServer install dir does not exist, exiting \033[0m"
    exit 1
  fi

}

