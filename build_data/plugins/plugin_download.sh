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
awk \
    -v base_url="${COMMUNITY_EXTENSION_PLUGIN_BASE_URL}" \
    -v gs_version="${GS_VERSION}" '
{
    printf "url = \"%s/geoserver-%s-SNAPSHOT-%s.zip\"\n", base_url, gs_version, $0
    printf "output = \"/work/community_plugins/%s.zip\"\n", $0
    print "--fail"
    print "--location"
    print ""
}' < "${COMMUNITY_PLUGINS_FILE}" >> /work/curl.cfg
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

# Download all plugins and tools
for attempt in {1..5}; do
    echo "Attempt $attempt of downloading plugins and agents"
    if curl --progress-bar -vK /work/curl.cfg; then
        echo "Download successful"
        break
    else
        echo "Download failed, retrying in 10 seconds..."
        sleep 10
    fi
done

# Write basic JMX config file
printf '%s\n' \
    'rules:' \
    '- pattern: ".*"' \
    > /work/telemetry/jmx_config.yaml