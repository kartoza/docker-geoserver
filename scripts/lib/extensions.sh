#!/usr/bin/env bash

############################################
# 1. Extension MANAGEMENT
############################################

download_extension() {
  curl --progress-bar -fL \
    -o "$3/$2.zip" "$1"
}

install_plugin() {
  local data_path="${1:-/community_plugins}"
  local ext="$2"

  [[ -f "${data_path}/${ext}.zip" ]] || return

  unzip -qq "${data_path}/${ext}.zip" -d /tmp/gs_plugin
  GEOSERVER_INSTALL_DIR="$(detect_install_dir)"

  cp -u /tmp/gs_plugin/*.jar \
     "${GEOSERVER_INSTALL_DIR}/webapps/${GEOSERVER_CONTEXT_ROOT}/WEB-INF/lib/"

  rm -rf /tmp/gs_plugin
}

############################################
# 2. Extension UTILITIES
############################################

generate_community_extensions_config() {
  local cfg_file="${COMMUNITY_PLUGINS_DIR}/curl.cfg"
  rm -f "$cfg_file"

  for ext in $(echo "${COMMUNITY_EXTENSIONS}" | tr ',' ' '); do
    local output_file="${COMMUNITY_PLUGINS_DIR}/${ext}.zip"

    if [[ -f "$output_file" ]]; then
      echo -e "[Entrypoint] Community Extension already exists, skipping download of : \e[1;31m $ext \033[0m"
      continue
    fi

    echo "url = \"${COMMUNITY_EXTENSION_PLUGIN_BASE_URL}/geoserver-${GS_VERSION}-SNAPSHOT-${ext}.zip\"" >> "$cfg_file"
    echo "output = \"${output_file}\"" >> "$cfg_file"
    echo "--fail" >> "$cfg_file"
    echo "--location" >> "$cfg_file"
    echo "" >> "$cfg_file"
  done
}

generate_stable_extensions_config() {
  local cfg_file="${STABLE_PLUGINS_DIR}/curl.cfg"
  rm -f "$cfg_file"

  local extensions

  if [[ "$ACTIVE_EXTENSIONS" != "$DEFAULT_EXTENSIONS" ]]; then
      extensions="${ACTIVE_EXTENSIONS}"
  else
      extensions="${DEFAULT_EXTENSIONS}"
  fi

  for ext in $(echo "${extensions}" | tr ',' ' '); do

    if echo "${DEFAULT_EXTENSIONS}" | grep -w "${ext}" >/dev/null; then
        output_file="${REQUIRED_PLUGINS_DIR}/${ext}.zip"
    else
        output_file="${STABLE_PLUGINS_DIR}/${ext}.zip"
    fi

    # Skip if already downloaded
    if [[ -f "$output_file" ]]; then
        echo -e "[Entrypoint] Extension already exists : \e[1;31m $ext \033[0m"
        continue
    fi

    plugin_url="${STABLE_PLUGIN_BASE_URL}/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-${ext}.zip"

    echo "url = \"${plugin_url}\"" >> "$cfg_file"
    echo "output = \"${output_file}\"" >> "$cfg_file"
    echo "--fail" >> "$cfg_file"
    echo "--location" >> "$cfg_file"
    echo "" >> "$cfg_file"

  done
}

############################################
# 3. EXTENSIONS (STABLE & COMMUNITY)
############################################

setup_stable_extensions(){

  generate_stable_extensions_config
  download_extensions_config "${STABLE_PLUGINS_DIR}/curl.cfg"

  local extensions

  if [[ "$ACTIVE_EXTENSIONS" != "$DEFAULT_EXTENSIONS" ]]; then
      extensions="${ACTIVE_EXTENSIONS}"
  else
      extensions="${DEFAULT_EXTENSIONS}"
  fi

  for ext in $(echo "${extensions}" | tr ',' ' '); do

      if echo "${DEFAULT_EXTENSIONS}" | grep -w "${ext}" >/dev/null; then
          install_plugin "${REQUIRED_PLUGINS_DIR}" "${ext}"
      else
          install_plugin "${STABLE_PLUGINS_DIR}" "${ext}"
      fi

  done
}

setup_community_extensions(){

  if [[ ! -z ${COMMUNITY_EXTENSIONS} ]]; then
    if  [[ ${FORCE_DOWNLOAD_COMMUNITY_EXTENSIONS} =~ [Tt][Rr][Uu][Ee] ]];then
      rm -rf ${COMMUNITY_PLUGINS_DIR}/*.zip
    fi

  generate_community_extensions_config
  download_extensions_config "${COMMUNITY_PLUGINS_DIR}/curl.cfg"

  for ext in $(echo "${COMMUNITY_EXTENSIONS}" | tr ',' ' '); do
      if [[ -f ${COMMUNITY_PLUGINS_DIR}/${ext}.zip ]]; then

        setup_jdbc_db_store
        setup_jdbc_db_config
        setup_hz_cluster
        install_plugin ${COMMUNITY_PLUGINS_DIR} "${ext}"
      fi
  done

fi

}



setup_extensions(){


  DEFAULT_EXTENSIONS=''
  for plugin in $(cat ${REQUIRED_PLUGINS_DIR}/required_plugins.txt); do
    if [ -z "$DEFAULT_EXTENSIONS" ]; then
      DEFAULT_EXTENSIONS=${plugin}
    else
      DEFAULT_EXTENSIONS=${DEFAULT_EXTENSIONS},${plugin}
    fi
  done

  if [[ -z ${ACTIVE_EXTENSIONS} ]];then
    ACTIVE_EXTENSIONS=${DEFAULT_EXTENSIONS},${STABLE_EXTENSIONS}
  fi

  # If FORCE_DOWNLOAD_STABLE_EXTENSIONS is true, remove all stable extensions
  if [[ ${FORCE_DOWNLOAD_STABLE_EXTENSIONS} =~ [Tt][Rr][Uu][Ee] ]]; then
    rm -rf ${STABLE_PLUGINS_DIR}/*.zip
    rm -rf ${REQUIRED_PLUGINS_DIR}/*.zip
  fi

  setup_stable_extensions
}



download_extensions_config() {
  local cfg_file="${1:-/work/curl.cfg}"

  # Only proceed if config exists and has content
  if [[ ! -s "$cfg_file" ]]; then
    echo "No extensions to download"
    return 0
  fi

  for attempt in {1..5}; do
    echo "Attempt $attempt of downloading plugins"

    if curl --progress-bar -K "$cfg_file"; then
      echo "Download successful"
      return 0
    else
      echo "Download failed, retrying in 5 seconds..."
      sleep 5
    fi
  done

  echo "Download failed after multiple attempts"
  return 1
}

############################################
# 4. S3 COMMUNITY EXTENSION
############################################

s3_config() {
  cat >"${GEOSERVER_DATA_DIR}"/s3.properties <<EOF
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
# 5. STATUS WRAPPERS (ENTRYPOINT CALLS)
############################################

setup_community_extensions_status() {
  export JDBC_CONFIG_ENABLED JDBC_IGNORE_PATHS JDBC_STORE_ENABLED POSTGRES_JNDI
  setup_community_extensions
}