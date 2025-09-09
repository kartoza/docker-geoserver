#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

# Run old Geoserver instance service

${VERSION} -f docker-compose.yml up -d geoserver

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} -f docker-compose.yml logs -f &
fi


services=("geoserver")

for service in "${services[@]}"; do
  echo "executing test for service $service"
  # Execute tests
  echo -e "[Unit Test] Test URL availability for: \e[1;31m $service \033[0m"
  test_url_availability http://localhost:8080/geoserver/rest/about/version.xml
  echo -e "\e[32m ---------------------------------------- \033[0m"
  echo -e "[Unit Test] Execute test for: \e[1;31m $service \033[0m"
  ${VERSION} -f docker-compose.yml exec $service /bin/bash /tests/test.sh

done

sleep 60

${VERSION} -f docker-compose.yml stop geoserver
${VERSION} -f docker-compose.yml up -d upgrade

services=("upgrade")

for service in "${services[@]}"; do
  echo "executing test for service $service"
  # Execute tests
  echo -e "[Unit Test] Test URL availability for: \e[1;31m $service \033[0m"
  test_url_availability http://localhost:8080/geoserver/rest/about/version.xml
  echo -e "\e[32m ---------------------------------------- \033[0m"
  echo -e "[Unit Test] Execute test for: \e[1;31m $service \033[0m"
  ${VERSION} -f docker-compose.yml exec $service /bin/bash /tests/test.sh

done

${VERSION} -f docker-compose.yml down -v
