#!/bin/bash
set -e

#!/usr/bin/env bash

set -o pipefail


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

#############################################
# Run functions
#############################################
setup_runtime_user
export_cluster_variables
create_required_directories
rename_context_root_if_needed
run_pre_start_hooks
configure_jvm
configure_telemetry
fix_permissions
start_geoserver_service