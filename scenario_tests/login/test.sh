#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

# Run service

${VERSION} up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} logs -f &
fi


services=("geoserver" "server" "credentials")
START_PORT=8081

for i in "${!services[@]}"; do
  service="${services[$i]}"
  PORT=$((START_PORT + i))

  # Set default values
  PASS="myawesomegeoserver"
  USER="admin"

  # Service-specific overrides
  if [[ "$service" == "server" ]]; then
    PASS=$(docker compose exec server cat /opt/geoserver/data_dir/security/pass.txt)
  elif [[ "$service" == "credentials" ]]; then
    USER="myadmin"
  fi

  sleep 30
  echo -e "[Unit Test] Test URL availability for: \e[1;31m $service \033[0m"
  test_url_availability "http://localhost:$PORT/geoserver/rest/about/version.xml" "$PASS" "$USER"

  echo -e "\e[32m ---------------------------------------- \033[0m"
  echo -e "[Unit Test] Execute test for: \e[1;31m $service \033[0m"
  ${VERSION} exec -T "$service" /bin/bash /tests/test.sh
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
  sleep 120
  echo -e "[Unit Test] Test URL availability for: \e[1;31m $service \033[0m"
  test_url_availability http://localhost:8081/geoserver/rest/about/version.xml fabulousgeoserver
  echo -e "\e[32m ---------------------------------------- \033[0m"
  echo -e "[Unit Test] Execute test for: \e[1;31m $service \033[0m"
  ${VERSION} exec -T $service /bin/bash /tests/test.sh

done

${VERSION} down -v
sed -i 's/fabulousgeoserver/myawesomegeoserver/g' docker-compose.yml