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

################################
#Test using internal jms cluster
################################
echo -e "\e[32m -------------------------------------------------------- \033[0m"
echo -e "[Unit Test] Running testing using internal: \e[1;31m JMS plugin \033[0m"

${VERSION} -f docker-compose.yml up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} -f docker-compose.yml logs -f &
fi


# Test Master
services=("master")

for service in "${services[@]}"; do

  # Execute tests
  test_url_availability http://localhost:8081/geoserver/rest/about/version.xml
  echo "Execute test for $service"
  ${VERSION} -f docker-compose.yml exec "${service}" /bin/bash /tests/test.sh

done

# Test Node
services=("node")

for service in "${services[@]}"; do

  # Execute tests
  test_url_availability http://localhost:8082/geoserver/rest/about/version.xml
  echo "Execute test for $service"
  ${VERSION} -f docker-compose.yml exec "${service}" /bin/bash /tests/test.sh

done

${VERSION} -f docker-compose.yml down -v

#############################
#Test using external ActiveMQ
#############################

echo -e "\e[32m -------------------------------------------------------- \033[0m"
echo -e "[Unit Test] Running testing using internal: \e[1;31m ActiveMQ \033[0m"

${VERSION} -f docker-compose-external.yml up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} -f docker-compose-external.yml logs -f &
fi



# Test Master
services=("master")

for service in "${services[@]}"; do

  # Execute tests
  test_url_availability http://localhost:8080/geoserver/rest/about/version.xml
  echo "Execute test for $service"
  ${VERSION} -f docker-compose.yml exec "${service}" /bin/bash /tests/test.sh

done

# Test Node
services=("node")

for service in "${services[@]}"; do

  # Execute tests
  test_url_availability http://localhost:8080/geoserver/rest/about/version.xml
  echo "Execute test for $service"
  ${VERSION} -f docker-compose-external.yml exec "${service}" /bin/bash /tests/test.sh

done

${VERSION} -f docker-compose-external.yml down -v