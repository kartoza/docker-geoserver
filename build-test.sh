#!/usr/bin/env bash
# For scenario testing purposes

if [[ $(dpkg -l | grep "docker-compose") > /dev/null ]];then
  docker-compose -f docker-compose-build.yml build geoserver-test
else
  docker compose -f docker-compose-build.yml build geoserver-test
fi
