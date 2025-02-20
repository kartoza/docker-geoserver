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

${VERSION} up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} logs -f &
fi


services=("geoserver" "server")

for service in "${services[@]}"; do

  # Execute tests
  if [[ $service == 'server' ]];then
    PORT=8082
    PASS=$(docker compose exec server cat /opt/geoserver/data_dir/security/pass.txt)
  else
    PORT=8081
    PASS="myawesomegeoserver"
  fi
  sleep 30
  test_url_availability http://localhost:$PORT/geoserver/rest/about/version.xml ${PASS}
  echo "Execute test for $service"
  ${VERSION} exec -T $service /bin/bash /tests/test.sh

done

${VERSION} down -v

# Test Updating passwords
${VERSION} up -d geoserver

${VERSION} stop

# Update password
sed -i 's/myawesomegeoserver/fabulousgeoserver/g' docker-compose.yml
# Bring the services up again
${VERSION} up -d geoserver

services=("geoserver")

for service in "${services[@]}"; do

  # Execute tests
  sleep 30
  test_url_availability http://localhost:8081/geoserver/rest/about/version.xml fabulousgeoserver
  echo "Execute test for $service"
  ${VERSION} exec -T $service /bin/bash /tests/test.sh

done

${VERSION} down -v
sed -i 's/fabulousgeoserver/myawesomegeoserver/g' docker-compose.yml