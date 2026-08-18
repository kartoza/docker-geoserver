#!/bin/bash
set -eux

# Default value for LIMIT_EXT_DOWNLOAD if not set
if [ -z "${LIMIT_EXT_DOWNLOAD:-}" ]; then
  LIMIT_EXT_DOWNLOAD=false
fi

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


# array of plugin directories
dirs=(
  /work/required_plugins
  /work/stable_plugins
  /work/community_plugins
  /work/geoserver_war
  /work/telemetry
)


for d in "${dirs[@]}"; do
  create_dir "$d"
done



download_libjpegturbo() {
  version="2.1.5.1"
  archs="amd64 arm64"

  for arch in $archs; do
    deb="libjpeg-turbo-official_${version}_${arch}.deb"

    [ -f "/work/required_plugins/${deb}" ] && continue

    curl -vfLo "/work/required_plugins/${deb}" \
      "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/${version}/${deb}"
  done
}
download_libjpegturbo

# Build a curl config to download all required plugins
awk '{print "url = \"'"${STABLE_PLUGIN_BASE_URL}/${GS_VERSION}"'/extensions/geoserver-'"${GS_VERSION}"'-"$0".zip\"\noutput = \"/work/required_plugins/"$0".zip\"\n--fail\n--location\n"}' < /work/required_plugins.txt > /work/curl.cfg

# Add in all stable plugins
setup_stable_plugin_download(){
  if [ "${LIMIT_EXT_DOWNLOAD,,}" = "true" ]; then
    head -n 5 /work/stable_plugins.txt > /work/stable_plugins_modified.txt
    STABLE_PLUGINS_FILE=/work/stable_plugins_modified.txt
  else
    STABLE_PLUGINS_FILE=/work/stable_plugins.txt
  fi
awk '{print "url = \"'"${STABLE_PLUGIN_BASE_URL}/${GS_VERSION}"'/extensions/geoserver-'"${GS_VERSION}"'-"$0".zip\"\noutput = \"/work/stable_plugins/"$0".zip\"\n--fail\n--location\n"}' < ${STABLE_PLUGINS_FILE} >> /work/curl.cfg

}

setup_stable_plugin_download

# Add in all community plugins
setup_community_plugin_download(){
  if [ "${LIMIT_EXT_DOWNLOAD,,}" = "true" ]; then
    head -n 5 /work/community_plugins.txt > /work/community_plugins_modified.txt
    COMMUNITY_PLUGINS_FILE=/work/community_plugins_modified.txt
  else
    COMMUNITY_PLUGINS_FILE=/work/community_plugins.txt
  fi
}

setup_community_plugin_download

# Add OpenTelemetry Java Agent
setup_open_telemetry(){
 echo "url = \"https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/${OTEL_VERSION}/opentelemetry-javaagent.jar\"" >> /work/curl.cfg
 echo "output = \"/work/telemetry/opentelemetry-javaagent.jar\"" >> /work/curl.cfg
 echo "--fail" >> /work/curl.cfg
 echo "--location" >> /work/curl.cfg
}

setup_open_telemetry
# Add Log4J JSON Layout jar

setup_log4j_configuration(){
 echo "url = \"https://search.maven.org/remotecontent?filepath=org/apache/logging/log4j/log4j-layout-template-json/${LOG4J_VERSION}/log4j-layout-template-json-${LOG4J_VERSION}.jar\"" >> /work/curl.cfg
 echo "output = \"/work/telemetry/log4j-layout-template-json.jar\"" >> /work/curl.cfg
 echo "--fail" >> /work/curl.cfg
 echo "--location" >> /work/curl.cfg
}

setup_log4j_configuration

# Add JMX Prometheus agent
setup_jmx_prometheus(){
  echo "url = \"https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${JMX_PROMETHEUS_VERSION}/jmx_prometheus_javaagent-${JMX_PROMETHEUS_VERSION}.jar\"" >> /work/curl.cfg
  echo "output = \"/work/telemetry/jmx_prometheus_javaagent.jar\"" >> /work/curl.cfg
  echo "--fail" >> /work/curl.cfg
  echo "--location" >> /work/curl.cfg
}

setup_jmx_prometheus

# Download GeoServer WAR
prepare_geoserver_release(){
  if [[ "${WAR_URL}" == *\.zip ]]; then
      destination="/work/geoserver_war/geoserver.zip"
      curl --progress-bar -fLvo "${destination}" "${WAR_URL}" || exit 1
  else
      destination="/work/geoserver_war/geoserver.war"
      curl --progress-bar -fLvo "${destination}" "${WAR_URL}" || exit 1
  fi
}

prepare_geoserver_release

# Download Jetty Services
prepare_extra_configs(){
  curl --progress-bar -fLvo /work/required_plugins/jetty-servlets.jar https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-servlets/11.0.9/jetty-servlets-11.0.9.jar

  # Download jetty-util
  curl --progress-bar -fLvo /work/required_plugins/jetty-util.jar https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-util/11.0.9/jetty-util-11.0.9.jar

  curl --progress-bar -fLvo /work/required_plugins/marlin.jar https://github.com/bourgesl/marlin-renderer/releases/download/v0_9_4_8/marlin-0.9.4.8-Unsafe-OpenJDK11.jar

}
prepare_extra_configs

# Download required plugins and tools. These artifacts are required for a
# usable image, so exhaust the retries and fail the build if they remain
# unavailable.
download_succeeded=false
for attempt in {1..5}; do
    echo "Attempt $attempt of downloading plugins and agents"
    if curl --progress-bar -vK /work/curl.cfg; then
        echo "Download successful"
        download_succeeded=true
        break
    else
        echo "Download failed, retrying in 10 seconds..."
        sleep 10
    fi
done

if [[ "${download_succeeded}" != "true" ]]; then
  echo "Required plugins or agents could not be downloaded" >&2
  exit 1
fi

download_community_plugins() {
  local failure_report=/work/community_plugin_download_failures.txt
  local connect_timeout="${COMMUNITY_PLUGIN_CONNECT_TIMEOUT:-10}"
  local max_time="${COMMUNITY_PLUGIN_MAX_TIME:-300}"
  local retries="${COMMUNITY_PLUGIN_RETRIES:-1}"
  local community_plugin_version="${GS_VERSION%.*}.0"
  local plugin url destination error_file validation_file curl_status error_message
  local failed_count=0
  local plugins=()

  if [[ -f /work/community_plugin_discovery_failure.txt ]]; then
    cp /work/community_plugin_discovery_failure.txt "${failure_report}"
    failed_count=1
  else
    : > "${failure_report}"
  fi
  mapfile -t plugins < <(sed -e '/^[[:space:]]*$/d' -e '/^[[:space:]]*#/d' "${COMMUNITY_PLUGINS_FILE}")

  record_failure() {
    local failed_plugin="$1"
    local reason="$2"

    printf '%s\t%s\n' "${failed_plugin}" "${reason}" >> "${failure_report}"
    echo "Community plugin ${failed_plugin} won't be available: ${reason}"
    failed_count=$((failed_count + 1))
  }

  # Avoid waiting once per plugin when the community build server itself is
  # unreachable. HTTP errors are acceptable here; this only checks whether a
  # connection can be established.
  if ! curl --silent --show-error --location --head \
      --connect-timeout "${connect_timeout}" \
      --max-time "${connect_timeout}" \
      --output /dev/null \
      "${COMMUNITY_EXTENSION_PLUGIN_BASE_URL}"; then
    for plugin in "${plugins[@]}"; do
      record_failure "${plugin}" "community plugin server is unreachable"
    done
  else
    for plugin in "${plugins[@]}"; do
      url="${COMMUNITY_EXTENSION_PLUGIN_BASE_URL}/geoserver-${community_plugin_version}-SNAPSHOT-${plugin}.zip"
      destination="/work/community_plugins/${plugin}.zip"
      error_file="/tmp/community-plugin-${plugin}.error"
      validation_file="/tmp/community-plugin-${plugin}.validation"

      rm -f "${destination}" "${error_file}" "${validation_file}"
      echo "Downloading community plugin ${plugin}"

      set +e
      curl --silent --show-error --fail --location \
        --connect-timeout "${connect_timeout}" \
        --max-time "${max_time}" \
        --retry "${retries}" \
        --retry-delay 2 \
        --retry-connrefused \
        --output "${destination}" \
        "${url}" 2>"${error_file}"
      curl_status=$?
      set -e

      if [[ "${curl_status}" -ne 0 ]]; then
        rm -f "${destination}"
        error_message="$(tail -n 1 "${error_file}" 2>/dev/null || true)"
        error_message="${error_message:-curl exited with status ${curl_status}}"
        record_failure "${plugin}" "download failed: ${error_message}"
        continue
      fi

      if ! unzip -tq "${destination}" >"${validation_file}" 2>&1; then
        error_message="$(tail -n 1 "${validation_file}" 2>/dev/null || true)"
        error_message="${error_message:-unzip integrity check failed}"
        rm -f "${destination}"
        record_failure "${plugin}" "ZIP integrity validation failed: ${error_message}"
        continue
      fi

      rm -f "${error_file}" "${validation_file}"
      echo "Community plugin ${plugin} downloaded and verified"
    done
  fi

  if [[ "${failed_count}" -eq 0 ]]; then
    echo "All requested community plugins were downloaded successfully"
  else
    echo "${failed_count} community plugin(s) won't be available. See ${failure_report}:"
    sed 's/^/  /' "${failure_report}"
  fi
}

download_community_plugins

# Write basic JMX config file
printf '%s\n' \
    'rules:' \
    '- pattern: ".*"' \
    > /work/telemetry/jmx_config.yaml
