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

  while true; do
    if [[ $(wget -S --spider --user admin --password ${PASS} ${URL}  2>&1 | grep 'HTTP/1.1 200') ]]; then
      echo "Rest endpoint ${URL} is available"
      break
    else
      echo "Rest endpoint ${URL} is not available, retrying in 5 seconds"
      sleep 5
    fi
  done

}
