#!/bin/bash
set -e

source /root/.bashrc

## Preparare the JVM command line arguments
export JAVA_OPTS="${JAVA_OPTS} ${GEOSERVER_OPTS}"

/scripts/update_passwords.sh
exec /usr/local/tomcat/bin/catalina.sh run
