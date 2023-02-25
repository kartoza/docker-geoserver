#!/usr/bin/env bash

set -e

source /scripts/env-data.sh

# execute tests
pushd /tests

cat << EOF
Settings used:

RECREATE_DATADIR: ${RECREATE_DATADIR}
DATADIR: ${DATADIR}
PGDATA: ${PGDATA}
INITDB_EXTRA_ARGS: ${INITDB_EXTRA_ARGS}
EOF

PGHOST=localhost \
PGDATABASE=gis \
PYTHONPATH=/lib \
  python3 -m unittest -v test_datadir.${TEST_CLASS}
