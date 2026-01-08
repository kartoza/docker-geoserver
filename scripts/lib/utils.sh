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

setup_google_fonts(){
  # Install google fonts based on https://github.com/google/fonts
# ADDED env variable to allow users to pass comma separated values
if [[ ! -z  ${GOOGLE_FONTS_NAMES}  ]];then
  git clone --filter=blob:none --no-checkout https://github.com/google/fonts.git
  cd $(pwd)/fonts
  git config core.sparsecheckout true

  if [[ "$GOOGLE_FONTS_NAMES" == *,* ]]; then
    for gfont in $(echo "${GOOGLE_FONTS_NAMES}" | tr ',' ' '); do
          if grep -Fxq "$gfont" /build_data/google_fonts.txt; then
            echo ofl/$gfont >> .git/info/sparse-checkout
          fi
    done
    git checkout main
    for gfont in $(echo "${GOOGLE_FONTS_NAMES}" | tr ',' ' '); do
          if grep -Fxq "$gfont" /build_data/google_fonts.txt; then
            cp -r  ofl/"${gfont}" /usr/share/fonts/truetype/
          fi
    done

  else
    if grep -Fxq "$GOOGLE_FONTS_NAMES" /build_data/google_fonts.txt; then
      echo ofl/$GOOGLE_FONTS_NAMES >> .git/info/sparse-checkout
    fi
    git checkout main
    if grep -Fxq "$GOOGLE_FONTS_NAMES" /build_data/google_fonts.txt; then
      git sparse-checkout set ofl/$GOOGLE_FONTS_NAMES
      cp -r ofl/$GOOGLE_FONTS_NAMES /usr/share/fonts/truetype/
    fi
  fi
  cd ..
  rm -rf fonts
fi
}

install_turbo(){
  # Install libjpeg-turbo
  system_architecture=$(dpkg --print-architecture)
  # Fixes https://github.com/kartoza/docker-geoserver/issues/673
  libjpeg_version=2.1.5.1
  libjpeg_deb_name="libjpeg-turbo-official_${libjpeg_version}_${system_architecture}.deb"
  libjpeg_deb="${resources_dir}/${libjpeg_deb_name}"
  if [[ ! -f "${libjpeg_deb}" ]]; then
    curl -vfLo "${libjpeg_deb}" "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/${libjpeg_version}/${libjpeg_deb_name}"
  fi

  dpkg -i "${libjpeg_deb}"
}

