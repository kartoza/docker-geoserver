#!/usr/bin/env bash

# Display test environment variable

cat << EOF
Test environment:

Compose Project : ${COMPOSE_PROJECT_NAME}
Compose File    : ${COMPOSE_PROJECT_FILE}
Image tag       : ${TAG}

EOF


export VERSION='docker compose'


function test_url_availability() {
  URL=$1
  PASS=$2
  USERNAME=$3
  if [ -z "$2" ]; then
    PASS=myawesomegeoserver
  fi
  if [ -z "$2" ]; then
    USERNAME=admin
  fi
  timeout=300
  start_time=$(date +%s)

  while true; do
    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))

    if [ $elapsed_time -ge $timeout ]; then
      echo "Timeout reached. Exiting trying to connect to service endpoint."
      exit 1
    fi



    result=$(wget -S --user ${USERNAME} --password ${PASS} --max-redirect=0 ${URL} 2>&1 | grep "HTTP/1.1 " | tail -n 1 | awk '{print $2}')

    if [[ $result -eq 200 ]]; then
      echo "Rest endpoint ${URL} is accessible with the provided credentials ${USERNAME} and password ${PASS}"
      if [[ -f version.xml ]];then
        rm version.xml
      fi
      break
    else
      echo "Access to ${URL}, with credentials username ${USERNAME} and password ${PASS} did not succeed, retrying in 5 seconds"
      sleep 5
    fi
  done

}


