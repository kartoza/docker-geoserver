#!/bin/sh
set -eux



GS_VERSION_LATEST="${GS_VERSION%.*}".x
GS_VERSION_COMMUNITY="${GS_VERSION_COMMUNITY:-${GS_VERSION%.*}.0}"
export GS_VERSION_COMMUNITY


python3 /work/stable_plugins.py ${GS_VERSION} https://sourceforge.net/projects/geoserver/files/GeoServer

python3 /work/community_plugins.py \
  "${GS_VERSION_LATEST}" \
  "${COMMUNITY_EXTENSION_PLUGIN_BASE_URL}" \
  "${GS_VERSION_COMMUNITY}"

