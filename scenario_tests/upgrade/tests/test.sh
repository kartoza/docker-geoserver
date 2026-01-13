#!/usr/bin/env bash

set -e

source_file() {
  local script="${1:-/scripts/lib/env-data.sh}"

  if [[ ! -f "$script" ]]; then
    echo "ERROR: Cannot source file: $script" >&2
    exit 1
  fi

  source "$script"
}

source_file "$1"



# execute tests
pushd /tests

cat << EOF
Settings used:

GEOSERVER_ADMIN_PASSWORD: ${GEOSERVER_ADMIN_PASSWORD}
GEOSERVER_ADMIN_USER: ${GEOSERVER_ADMIN_USER}
EOF

python3 -m unittest -v ${TEST_CLASS}
