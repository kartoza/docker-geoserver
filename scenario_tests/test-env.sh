#!/usr/bin/env bash

# Display test environment variable

cat << EOF
Test environment:

Compose Project : ${COMPOSE_PROJECT_NAME}
Compose File    : ${COMPOSE_PROJECT_FILE}
Image tag       : ${TAG}

EOF

function test_url_availability() {
  URL=$1
  PASS=$2
  if [ -z "$2" ]; then
    PASS=myawesomegeoserver
  fi
  timeout=300
  start_time=$(date +%s)

  while true; do
    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))

    if [ $elapsed_time -ge $timeout ]; then
      echo "Timeout reached. Exiting."
      exit 1
    fi
    if [[ $(wget -S --spider --user admin --password ${PASS} ${URL}  2>&1 | grep 'HTTP/1.1 200') ]]; then
      echo "Rest endpoint ${URL} is available"
      break
    else
      echo "Rest endpoint ${URL} is not available, retrying in 5 seconds"
      sleep 5
    fi
  done

}


