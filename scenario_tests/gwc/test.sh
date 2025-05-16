#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

# Run service

${VERSION} -f docker-compose-gwc.yml up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} -f docker-compose-gwc.yml logs -f &
fi




services=("geoserver")

for service in "${services[@]}"; do

  # Execute tests
  echo -e "[Unit Test] Test URL availability for: \e[1;31m $service \033[0m"
  test_url_availability http://localhost:8080/geoserver/rest/about/version.xml
  ${VERSION} -f docker-compose-gwc.yml ps
  echo -e "\e[32m ---------------------------------------- \033[0m"
  echo -e "[Unit Test] Execute test for: \e[1;31m $service \033[0m"
  ${VERSION} -f docker-compose-gwc.yml exec  $service /bin/bash /tests/test.sh

done

${VERSION} -f docker-compose-gwc.yml down -v
