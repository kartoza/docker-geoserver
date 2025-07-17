#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

# Run service

${VERSION} up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} logs -f &
fi

services=("geoserver_one" "geoserver_two")
for index in "${!services[@]}"; do
  read service <<< "${services[$index]}"
  PORT="808$((index +1))"
  METRICS_PORT="123$((index +1))"

  sleep 30
  test_url_availability http://localhost:$PORT/geoserver/rest/about/version.xml
  echo "Execute test for $service"
  
  if ! wget -q --spider http://localhost:$METRICS_PORT/metrics; then
    echo "ERROR: Metrics endpoint not available for $service at port $METRICS_PORT"
    exit 1
  fi

done

${VERSION} down -v