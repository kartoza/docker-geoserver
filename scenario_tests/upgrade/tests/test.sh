#!/usr/bin/env bash

set -e


local script="${1:-/scripts/lib/env-data.sh}"
source ${script}

# execute tests
pushd /tests

cat << EOF
Settings used:

GEOSERVER_ADMIN_PASSWORD: ${GEOSERVER_ADMIN_PASSWORD}
GEOSERVER_ADMIN_USER: ${GEOSERVER_ADMIN_USER}
EOF

python3 -m unittest -v ${TEST_CLASS}
