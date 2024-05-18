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

# JNDI store
${VERSION} -f docker-compose-postgis-jndi.yml up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} -f docker-compose-postgis-jndi.yml logs -f &
fi



services=("geoserver")

for service in "${services[@]}"; do

  # Execute tests
  test_url_availability http://localhost:8080/geoserver/rest/about/version.xml
  echo "Execute test for $service"
  ${VERSION} -f docker-compose-postgis-jndi.yml exec $service /bin/bash /tests/test.sh

done

${VERSION} -f docker-compose-postgis-jndi.yml down -v

# Run GDAL
${VERSION} -f docker-compose-gdal.yml up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} -f docker-compose-gdal.yml logs -f &
fi




services=("geoserver")

for service in "${services[@]}"; do

  # Execute tests
  test_url_availability http://localhost:8080/geoserver/rest/about/version.xml
  echo "Execute test for $service"
  ${VERSION} -f docker-compose-gdal.yml exec $service /bin/bash /tests/test.sh

done

${VERSION} -f docker-compose-gdal.yml down -v
