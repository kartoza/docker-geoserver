#!/bin/sh
set -eux

mkdir -p /work/required_plugins
mkdir -p /work/stable_plugins
mkdir -p /work/community_plugins
mkdir -p /work/geoserver_war/

# Build a curl config to download all required plugins
awk '{print "url = \"'"${STABLE_PLUGIN_BASE_URL}/${GS_VERSION}"'/extensions/geoserver-'"${GS_VERSION}"'-"$0".zip\"\noutput = \"/work/required_plugins/"$0".zip\"\n--fail\n--location\n"}' < /work/required_plugins.txt > /work/curl.cfg


# Add in all stable plugins
awk '{print "url = \"'"${STABLE_PLUGIN_BASE_URL}/${GS_VERSION}"'/extensions/geoserver-'"${GS_VERSION}"'-"$0".zip\"\noutput = \"/work/stable_plugins/"$0".zip\"\n--fail\n--location\n"}' < /work/stable_plugins.txt >> /work/curl.cfg



# Add in all community plugins
awk '{print "url = \"https://build.geoserver.org/geoserver/'"${GS_VERSION:0:5}"'x/community-latest/geoserver-'"${GS_VERSION:0:4}"'-SNAPSHOT-"$0".zip\"\noutput = \"/work/community_plugins/"$0".zip\"\n--fail\n--location\n"}' < /work/community_plugins.txt  >> /work/curl.cfg


if [[ "${WAR_URL}" == *\.zip ]]; then
    destination="/work/geoserver_war/geoserver.zip"
    curl --progress-bar -fLvo "${destination}" "${WAR_URL}" || exit 1
  else
    destination=/work/geoserver_war/geoserver.war
    curl --progress-bar -fLvo "${destination}" "${WAR_URL}" || exit 1
fi

# Download Jetty Services
curl -vfLo /work/required_plugins/jetty-servlets.jar https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-servlets/11.0.9/jetty-servlets-11.0.9.jar

# Download jetty-util
curl -vfLo /work/required_plugins/jetty-util.jar https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-util/11.0.9/jetty-util-11.0.9.jar



# Download everything!
for attempt in {1..5}; do
    echo "Attempt $attempt of downloading plugins"
    if curl --progress-bar -vK /work/curl.cfg; then
        echo "Download successful"
        break
    else
        echo "Download failed, retrying in 10 seconds..."
        sleep 10
    fi
done
