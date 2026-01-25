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
TEST_URL_PATH="/geoserver/rest/about/version.xml"

DEFAULT_USER="admin"
DEFAULT_PASS="myawesomegeoserver"

# ------------------------
# Helper: resolve credentials per service
# ------------------------
get_credentials() {
  local service="$1"

  case "$service" in
    server)
      USER="admin"
      PASS="$(docker compose exec -T server cat /opt/geoserver/data_dir/security/pass.txt)"
      ;;
    credentials)
      USER="myadmin"
      PASS="$DEFAULT_PASS"
      ;;
    *)
      USER="$DEFAULT_USER"
      PASS="$DEFAULT_PASS"
      ;;
  esac
}


# ------------------------
# Helper: run standard tests
# ------------------------
run_tests() {
  local service="$1"
  local port="$2"
  local user="$3"
  local pass="$4"

  echo -e "[Unit Test] Test URL availability for: \e[1;31m $service \033[0m"
  test_url_availability "http://localhost:${port}${TEST_URL_PATH}" "$pass" "$user"

  echo -e "\e[32m ---------------------------------------- \033[0m"
  echo -e "[Unit Test] Execute test for: \e[1;31m $service \033[0m"

  ${VERSION:-docker compose} exec -T "$service" /bin/bash /tests/test.sh
}

# ------------------------
# Main loop
# ------------------------
for idx in "${!services[@]}"; do
  service="${services[$idx]}"
  PORT=$((START_PORT + idx))

  if [[ "$service" != "users" ]]; then
    get_credentials "$service"
    run_tests "$service" "$PORT" "$USER" "$PASS"
    continue
  fi

  # ------------------------
  # Users service (multi-user tests)
  # ------------------------
  GEOSERVER_ADMIN_PASSWORD="myawesomegeoserver,mygeoserver,mysample"
  GEOSERVER_ADMIN_USER="foo,myadmin,sample"

  IFS=',' read -ra geopass <<< "$GEOSERVER_ADMIN_PASSWORD"
  IFS=',' read -ra geouser <<< "$GEOSERVER_ADMIN_USER"

  for uidx in "${!geopass[@]}"; do
    USER_NAME="${geouser[$uidx]}"
    PASSWORD="${geopass[$uidx]}"

    echo -e "[Unit Test] Test URL availability for: \e[1;31m users \033[0m (user: $USER_NAME)"
    test_url_availability \
      "http://localhost:${PORT}${TEST_URL_PATH}" \
      "$PASSWORD" \
      "$USER_NAME"

    echo "Execute test for users"
    docker compose exec -T users /bin/bash /tests/test.sh
  done
done

docker compose down -v

