#!/bin/sh
set -eux


VERSION=$(cat /tmp/pass.txt)
GS_VERSION_LATEST="${VERSION:0:5}"x

cd  /work/

python3 stable_plugins.py ${VERSION} https://sourceforge.net/projects/geoserver/files/GeoServer

python3 community_plugins.py  ${GS_VERSION_LATEST}



