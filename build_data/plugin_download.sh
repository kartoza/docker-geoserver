#!/bin/sh
set -eux

mkdir -p /work/required_plugins
mkdir -p /work/stable_plugins
mkdir -p /work/community_plugins

# Build a curl config to download all required plugins
awk '{print "url = \"https://sourceforge.net/projects/geoserver/files/GeoServer/'"${GS_VERSION}"'/extensions/geoserver-'"${GS_VERSION}"'-"$0".zip\"\noutput = \"/work/required_plugins/"$0".zip\"\n--fail\n--location\n"}' < /work/required_plugins.txt > /work/curl.cfg

if [ "${DOWNLOAD_ALL_STABLE_EXTENSIONS}" == "1" ]; then
    # Add in all stable plugins
    awk '{print "url = \"https://sourceforge.net/projects/geoserver/files/GeoServer/'"${GS_VERSION}"'/extensions/geoserver-'"${GS_VERSION}"'-"$0".zip\"\noutput = \"/work/stable_plugins/"$0".zip\"\n--fail\n--location\n"}' < /work/stable_plugins.txt >> /work/curl.cfg
fi

if [ "${DOWNLOAD_ALL_COMMUNITY_EXTENSIONS}" == "1" ]; then
    # Add in all community plugins
    awk '{print "url = \"https://build.geoserver.org/geoserver/'"${GS_VERSION:0:5}"'x/community-latest/geoserver-'"${GS_VERSION:0:4}"'-SNAPSHOT-"$0".zip\"\noutput = \"/work/community_plugins/"$0".zip\"\n--fail\n--location\n"}' < /work/community_plugins.txt  >> /work/curl.cfg
fi

# Download everything!
curl --fail-early -vK /work/curl.cfg
