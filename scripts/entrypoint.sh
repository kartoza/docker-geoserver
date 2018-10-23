#!/bin/bash
set -e

source /root/.bashrc

/scripts/update_passwords.sh
exec /usr/local/tomcat/bin/catalina.sh run
