#!/usr/bin/env bash

set -e

source ../test-env.sh

cleanup() {
  ${VERSION} down -v
}
trap cleanup EXIT

${VERSION} up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} logs -f &
fi

for attempt in $(seq 1 60); do
  if curl --fail --silent --output /dev/null \
    --user admin:myawesomegeoserver \
    'http://localhost:8085/geoserver/rest/about/version.xml'; then
    break
  fi

  if [[ "${attempt}" -eq 60 ]]; then
    echo 'GeoServer did not become ready within 300 seconds' >&2
    ${VERSION} logs geoserver >&2
    exit 1
  fi

  sleep 5
done

${VERSION} exec -T geoserver /bin/bash /tests/test.sh
