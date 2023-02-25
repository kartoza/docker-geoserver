#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

if [[ $(dpkg -l | grep "docker-compose") > /dev/null ]];then
    VERSION='docker-compose'
  else
    VERSION='docker compose'
fi


# Run service
${VERSION} up -d pg-default-md5 pg-new-md5 pg-default-scram pg-default-md5-gosu pg-new-md5-gosu pg-default-scram-gosu

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} logs -f &
fi

sleep 60

services=("pg-default-md5" "pg-new-md5" "pg-default-scram" "pg-default-md5-gosu" "pg-new-md5-gosu" "pg-default-scram-gosu")

for service in "${services[@]}"; do

  # Execute tests
  until ${VERSION} exec -T $service pg_isready; do
    sleep 5
    echo "Wait service to be ready"
  done;
  echo "Execute test for $service"
  ${VERSION} exec -T $service /bin/bash /tests/test.sh

done


${VERSION} down -v
