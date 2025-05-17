#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

# Run service

${VERSION} up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} logs -f &
fi

services=("geoserver_one" "geoserver_two" "geoserver_three")
for index in "${!services[@]}"; do
  read service <<< "${services[$index]}"
  PORT="808$((index +1))"

  sleep 30
  test_url_availability http://localhost:$PORT/geoserver/rest/about/version.xml
  echo "Execute test for $service"
  ${VERSION} exec -T $service /bin/bash /tests/test.sh

done

${VERSION} down -v