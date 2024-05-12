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

####################################
#Test using default created password
#####################################
echo -e "[Unit Test] Running testing using password from env : \e[1;31m Geoserver password \033[0m"

${VERSION} up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} logs -f &
fi

sleep 30


services=("geoserver")

for service in "${services[@]}"; do

  # Execute tests
  sleep 60
  echo "Execute test for $service"
  ${VERSION} exec -T "${service}" /bin/bash /tests/test.sh

done

${VERSION} down -v

####################################
#Test using updated password
#####################################
echo -e "[Unit Test] Running testing using updated password from env : \e[1;31m Geoserver password \033[0m"
sleep 5
sed -i 's/foobar/foobar#geoserver/g' docker-compose.yml
# Bring the services up again
${VERSION} up -d geoserver

services=("geoserver")

for service in "${services[@]}"; do

  # Execute tests
  sleep 60
  echo "Execute test for $service"
  ${VERSION} exec -T "${service}" /bin/bash /tests/test.sh

done

${VERSION} down -v
sed -i 's/foobar#geoserver/foobar/g' docker-compose.yml