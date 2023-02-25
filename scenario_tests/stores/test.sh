#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

if [[ $(dpkg -l | grep "docker-compose") > /dev/null ]];then
    VERSION='docker-compose'
  else
    VERSION='docker compose'
fi


# Run services
${VERSION} up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} logs -f &
fi

sleep 30

services=("geoserver")

for service in "${services[@]}"; do

  # Execute tests
  until ${VERSION} exec -T $service pg_isready; do
    sleep 5
    echo "Wait service to be ready"
  done;
  echo "Execute test for $service"
  ${VERSION} exec -T $service /bin/bash /tests/test.sh

done



${VERSION} -f docker-compose.yml down -v