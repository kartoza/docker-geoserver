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

${VERSION} -f docker-compose.yml up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} -f docker-compose.yml logs -f &
fi

sleep 60

# Test Master
services=("master")

for service in "${services[@]}"; do

  # Execute tests
  sleep 60
  echo "Execute test for $service"
  ${VERSION} -f docker-compose.yml exec "${service}" /bin/bash /tests/test.sh

done

# Test Node
services=("node")

for service in "${services[@]}"; do

  # Execute tests
  sleep 60
  echo "Execute test for $service"
  ${VERSION} -f docker-compose.yml exec "${service}" /bin/bash /tests/test.sh

done

${VERSION} -f docker-compose.yml down -v
