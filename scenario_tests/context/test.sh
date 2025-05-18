#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

# Run service

####################################
#Test using default created password
#####################################
echo -e "[Unit Test] Running GEOSERVER_CONTEXT_ROOT tests with GEOSERVER_CONTEXT_ROOT set to  foobar"

${VERSION} up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} logs -f &
fi


# Set default values
PASS="myawesomegeoserver"
USER="admin"

services=("geoserver")

for service in "${services[@]}"; do


  # Execute tests
  echo -e "[Unit Test] Test URL availability for: \e[1;31m $service \033[0m"
  test_url_availability http://localhost:8080/foobar/rest/about/version.xml "$PASS" "$USER"
  echo "Execute test for $service"
  ${VERSION} exec -T "${service}" /bin/bash /tests/test.sh

done

${VERSION} down -v

####################################
#Test using updated password
#####################################
echo -e "[Unit Test]  Running GEOSERVER_CONTEXT_ROOT tests with GEOSERVER_CONTEXT_ROOT set to foobar#geoserver"
sed -i 's/foobar/foobar#geoserver/g' docker-compose.yml
# Bring the services up again
${VERSION} up -d geoserver

services=("geoserver")

for service in "${services[@]}"; do

  # Execute tests
  echo -e "[Unit Test] Test URL availability for: \e[1;31m $service \033[0m"
  test_url_availability http://localhost:8080/foobar/geoserver/rest/about/version.xml "$PASS" "$USER"
  echo -e "\e[32m ---------------------------------------- \033[0m"
  echo -e "[Unit Test] Execute test for: \e[1;31m $service \033[0m"
  ${VERSION} exec -T "${service}" /bin/bash /tests/test.sh

done

${VERSION} down -v
sed -i 's/foobar#geoserver/foobar/g' docker-compose.yml