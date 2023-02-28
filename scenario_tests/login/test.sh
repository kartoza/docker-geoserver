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
echo $docker compose
docker compose up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  docker compose logs -f &
fi

sleep 30


services=("geoserver")

for service in "${services[@]}"; do

  # Execute tests
  sleep 60
  echo "Execute test for $service"
  docker compose exec -T $service /bin/bash /tests/test.sh

done

docker compose down -v
