#!/bin/sh
set -eux


VERSION=$(cat /tmp/pass.txt)
GS_VERSION_LATEST="${VERSION:0:5}"x


python3 /work/stable_plugins.py ${VERSION} https://sourceforge.net/projects/geoserver/files/GeoServer

python3 /work/community_plugins.py  ${GS_VERSION_LATEST}



