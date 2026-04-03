#!/bin/bash
set -e


figlet -t "Kartoza Docker GeoServer"

#############################################
# Bootstrap
#############################################
# Import env and functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
resources_dir="/tmp/resources"

source "${SCRIPT_DIR}/lib/env-data.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/logging.sh"
source "${SCRIPT_DIR}/lib/database.sh"
source "${SCRIPT_DIR}/lib/geoserver.sh"
source "${SCRIPT_DIR}/lib/tomcat.sh"
source "${SCRIPT_DIR}/lib/cluster.sh"
source "${SCRIPT_DIR}/lib/extensions.sh"

#############################################
# Run functions
#############################################

# Gosu preparations
setup_geoserver_users
create_entrypoint_directories
rename_geoserver_context_root
set_vars
run_pre_start_hooks
configure_jvm
configure_telemetry
fix_permissions
start_geoserver_service


