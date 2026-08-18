#!/bin/sh
set -eux



GS_VERSION_LATEST="${GS_VERSION%.*}".x


python3 /work/stable_plugins.py ${GS_VERSION} https://sourceforge.net/projects/geoserver/files/GeoServer

python3 /work/community_plugins.py \
  "${GS_VERSION_LATEST}" \
  "${COMMUNITY_EXTENSION_PLUGIN_BASE_URL}"


