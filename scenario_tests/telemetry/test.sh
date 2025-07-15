#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

# Run service

${VERSION} up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} logs -f &
fi

services=("geoserver_one")
for index in "${!services[@]}"; do
  read service <<< "${services[$index]}"
  PORT="808$((index +1))"

  sleep 30
  test_url_availability http://localhost:$PORT/geoserver/rest/about/version.xml
  echo "Execute test for $service"
  
  # Check if OpenTelemetry Collector is running
  if ! docker ps | grep -q "otel/opentelemetry-collector"; then
    echo "ERROR: OpenTelemetry Collector is not running for $service"
    exit 1
  fi 

  # In OpenTelemetry logs check if (using grep) service.name: Str(geoserver) exists
  if ! docker logs opentelemetry_collector  2>&1 | sed -n '/service\.name: Str(geoserver)/p'; then
    echo "ERROR: OpenTelemetry logs do not contain service.name for geoserver"
    exit 1
  fi

done

${VERSION} down -v