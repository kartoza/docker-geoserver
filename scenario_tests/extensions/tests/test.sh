#!/usr/bin/env bash

set -e

source /scripts/env-data.sh

# execute tests
pushd /tests

cat << EOF
Settings used:

POSTGRES_MULTIPLE_EXTENSIONS: ${POSTGRES_MULTIPLE_EXTENSIONS}
EOF

POSTGRES_MULTIPLE_EXTENSIONS=$POSTGRES_MULTIPLE_EXTENSIONS \
PGHOST=localhost \
PGDATABASE=gis \
PYTHONPATH=/lib \
  python3 -m unittest -v ${TEST_CLASS}
