#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

if [[ $(dpkg -l | grep "docker-compose") > /dev/null ]];then
    VERSION='docker-compose'
  else
    VERSION='docker compose'
fi

# This test is special
# It is used to check the meta level of the setup.

# Print logs
if [[ -n "${PRINT_TEST_LOGS}" ]]; then
    ${VERSION} -f docker-compose-gs.yml logs -f &
fi

# Recreate containers with the same setup as pg-new and pg-default
# Try to make sure that container recreation is successful
echo "### Checking Container Recreation"
${VERSION} -f docker-compose-gs.yml down
${VERSION} -f docker-compose-gs.yml up -d pg-default pg-new pg-recreate

sleep 60

services=("pg-default" "pg-new" "pg-recreate")

for service in "${services[@]}"; do

    # Execute tests
    until ${VERSION} -f docker-compose-gs.yml exec -T $service pg_isready; do
        sleep 5
        echo "Wait service to be ready"
    done;
    echo "Execute test for $service"
    ${VERSION} -f docker-compose-gs.yml exec -T $service /bin/bash /tests/test.sh

done

# Check the wrong setup must have warned that nested custom pg_wal location
# is prevented
echo "### Checking Error Message on nested pg_wal location"
service="pg-custom-waldir-wrong"
${VERSION} -f docker-compose-gs.yml up -d pg-custom-waldir-wrong

sleep 60

# Loop until we found error message
while true; do
    if [[ -n "$(${VERSION} -f docker-compose-gs.yml logs $service | grep 'Error')" && \
        -n "$(${VERSION} -f docker-compose-gs.yml logs $service | grep 'POSTGRES_INITDB_WALDIR should not be set to be inside DATADIR or PGDATA.')" ]]; then
        break
    fi
    sleep 5
done;

${VERSION} -f docker-compose-gs.yml down

# Check that the correct custom initdb waldir works, twice after container restart.
echo "### Checking custom POSTGRES_INITDB_WALDIR should work"
service="pg-custom-waldir-correct"
for ((i=1;i<=2;i++)); do
    echo "attempt $i"
    ${VERSION} -f docker-compose-gs.yml up -d $service
    sleep 60
    until ${VERSION} -f docker-compose-gs.yml exec -T $service pg_isready; do
        sleep 5
        echo "Wait service to be ready"
    done;
    echo "Execute test for $service"
    ${VERSION} -f docker-compose-gs.yml exec -T $service /bin/bash /tests/test.sh
    ${VERSION} -f docker-compose-gs.yml down
done

# Check that if the variable POSTGRES_INITBD_WALDIR doesn't match with pg_wal symlink,
# then give warning, but proceeds if the the mount is still correct
echo "### Checking raise warning if custom POSTGRES_INITDB_WALDIR does not match"
service="pg-custom-waldir-not-match-1"
${VERSION} -f docker-compose-gs.yml up -d $service
sleep 60
# Loop until we found warning message
while true; do
    if [[ -n "$(${VERSION} -f docker-compose-gs.yml logs $service | grep 'Warning')" && \
        -n "$(${VERSION} -f docker-compose-gs.yml logs $service | grep 'POSTGRES_INITDB_WALDIR is not the same as what pg_wal is pointing to.')" ]]; then
        break
    fi
    sleep 5
done;
until ${VERSION} -f docker-compose-gs.yml exec -T $service pg_isready; do
    sleep 5
    echo "Wait service to be ready"
done;
echo "Execute test for $service"
${VERSION} -f docker-compose-gs.yml exec -T $service /bin/bash /tests/test.sh
${VERSION} -f docker-compose-gs.yml down

# Check that if the pg_wal is empty, then something is wrong and we should exit
echo "### Checking Error and Exit if pg_wal is empty"
service="pg-custom-waldir-not-match-2"
${VERSION} -f docker-compose-gs.yml up -d $service
sleep 60
# Loop until we found warning message
warning_text="Can't proceed because \"/opt/mypostgis/data/pg_wal\" directory is empty."
while true; do
    if [[ -n "$(${VERSION} -f docker-compose-gs.yml logs $service | grep 'Error')" && \
        -n "$(${VERSION} -f docker-compose-gs.yml logs $service | grep "$warning_text")" ]]; then
        break
    fi
    sleep 5
done;

${VERSION} -f docker-compose-gs.yml down -v
