#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

# Run service

${VERSION} up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} logs -f &
fi


services=("geoserver" "server" "credentials" "users")
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


  if [[ "$service" != "users" ]];then
    echo -e "[Unit Test] Test URL availability for: \e[1;31m $service \033[0m"
    test_url_availability "http://localhost:$PORT/geoserver/rest/about/version.xml" "$PASS" "$USER"
    echo -e "\e[32m ---------------------------------------- \033[0m"
    echo -e "[Unit Test] Execute test for: \e[1;31m $service \033[0m"
    ${VERSION} exec -T "$service" /bin/bash /tests/test.sh
  else
    # Execute tests
    GEOSERVER_ADMIN_PASSWORD=myawesomegeoserver,mygeoserver,mysample
    GEOSERVER_ADMIN_USER=foo,myadmin,sample
    COUNT_GEOSERVER_ADMIN_PASSWORD=$(echo "$GEOSERVER_ADMIN_PASSWORD" | tr ',' '\n' | wc -l)
    IFS=','
    read -a geopass <<< "$GEOSERVER_ADMIN_PASSWORD"
    read -a geouser <<< "$GEOSERVER_ADMIN_USER"
    services=("users")
    for i in "${!services[@]}"; do
      service="${services[$i]}"
      for ((i = 0; i < ${COUNT_GEOSERVER_ADMIN_PASSWORD}; i++)); do
              USER="${geouser[$i]}"
              PASS="${geopass[$i]}"
              echo -e "[Unit Test] Test URL availability for: \e[1;31m $service with user $USER and pass $PASS \033[0m"
              test_url_availability http://localhost:$PORT/geoserver/rest/about/version.xml ${PASS} ${USER}
              echo "Execute test for $service"
              docker compose exec -T "$service" /bin/bash /tests/test.sh
      done
    done

  fi

done


docker compose down -v