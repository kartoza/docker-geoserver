#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

# Run service
if [[ $(dpkg -l | grep "docker-compose") > /dev/null ]];then
    VERSION='docker-compose'
  else
    VERSION='docker compose'
fi

${VERSION} -f docker-compose-postgis-jndi.yml up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} -f docker-compose-postgis-jndi.yml logs -f &
fi

sleep 60


services=("geoserver")

for service in "${services[@]}"; do

  # Execute tests
  sleep 60
  echo "Execute test for $service"
  ${VERSION} -f docker-compose-postgis-jndi.yml exec $service /bin/bash /tests/test.sh

done

${VERSION} -f docker-compose-postgis-jndi.yml down -v
