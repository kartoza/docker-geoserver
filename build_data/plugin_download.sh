#!/bin/sh
set -eux

mkdir -p /work/required_plugins
mkdir -p /work/stable_plugins
mkdir -p /work/community_plugins
mkdir -p /work/geoserver_war
mkdir -p /work/telemetry

# Build a curl config to download all required plugins
awk '{print "url = \"'"${STABLE_PLUGIN_BASE_URL}/${GS_VERSION}"'/extensions/geoserver-'"${GS_VERSION}"'-"$0".zip\"\noutput = \"/work/required_plugins/"$0".zip\"\n--fail\n--location\n"}' < /work/required_plugins.txt > /work/curl.cfg

# Add in all stable plugins
awk '{print "url = \"'"${STABLE_PLUGIN_BASE_URL}/${GS_VERSION}"'/extensions/geoserver-'"${GS_VERSION}"'-"$0".zip\"\noutput = \"/work/stable_plugins/"$0".zip\"\n--fail\n--location\n"}' < /work/stable_plugins.txt >> /work/curl.cfg

# Add in all community plugins
awk '{print "url = \"https://build.geoserver.org/geoserver/'"${GS_VERSION:0:5}"'x/community-latest/geoserver-'"${GS_VERSION:0:4}"'-SNAPSHOT-"$0".zip\"\noutput = \"/work/community_plugins/"$0".zip\"\n--fail\n--location\n"}' < /work/community_plugins.txt >> /work/curl.cfg

# Add OpenTelemetry Java Agent
echo "url = \"https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/${OTEL_VERSION}/opentelemetry-javaagent.jar\"" >> /work/curl.cfg
echo "output = \"/work/telemetry/opentelemetry-javaagent.jar\"" >> /work/curl.cfg
echo "--fail" >> /work/curl.cfg
echo "--location" >> /work/curl.cfg

# Add Log4J JSON Layout jar
echo "url = \"https://search.maven.org/remotecontent?filepath=org/apache/logging/log4j/log4j-layout-template-json/${LOG4J_VERSION}/log4j-layout-template-json-${LOG4J_VERSION}.jar\"" >> /work/curl.cfg
echo "output = \"/work/telemetry/log4j-layout-template-json.jar\"" >> /work/curl.cfg
echo "--fail" >> /work/curl.cfg
echo "--location" >> /work/curl.cfg

# Add JMX Prometheus agent
echo "url = \"https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${JMX_PROMETHEUS_VERSION}/jmx_prometheus_javaagent-${JMX_PROMETHEUS_VERSION}.jar\"" >> /work/curl.cfg
echo "output = \"/work/telemetry/jmx_prometheus_javaagent.jar\"" >> /work/curl.cfg
echo "--fail" >> /work/curl.cfg
echo "--location" >> /work/curl.cfg

# Download GeoServer WAR
if [[ "${WAR_URL}" == *\.zip ]]; then
    destination="/work/geoserver_war/geoserver.zip"
    curl --progress-bar -fLvo "${destination}" "${WAR_URL}" || exit 1
else
    destination="/work/geoserver_war/geoserver.war"
    curl --progress-bar -fLvo "${destination}" "${WAR_URL}" || exit 1
fi

# Download Jetty Services
curl --progress-bar -fLvo /work/required_plugins/jetty-servlets.jar https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-servlets/11.0.9/jetty-servlets-11.0.9.jar

# Download jetty-util
curl --progress-bar -fLvo /work/required_plugins/jetty-util.jar https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-util/11.0.9/jetty-util-11.0.9.jar

curl --progress-bar -fLvo /work/required_plugins/marlin.jar https://github.com/bourgesl/marlin-renderer/releases/download/v0_9_4_8/marlin-0.9.4.8-Unsafe-OpenJDK11.jar

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