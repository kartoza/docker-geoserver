#!/usr/bin/env bash
# Download geoserver extensions and other resources

SCRIPT_DIR="/scripts"
source "${SCRIPT_DIR}/lib/env-data.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/logging.sh"
source "${SCRIPT_DIR}/lib/database.sh"
source "${SCRIPT_DIR}/lib/geoserver.sh"
source "${SCRIPT_DIR}/lib/tomcat.sh"
source "${SCRIPT_DIR}/lib/cluster.sh"

resources_dir="/tmp/resources"
GS_VERSION=$(cat /scripts/geoserver_version.txt)

# ---------------------------
# Main execution flow
# ---------------------------

create_required_dirs
install_geoserver_core
install_plugin_dependency
install_required_jars
apply_overlays
package_tomcat_webapp
patch_tomcat_server_info
set_restrictive_umask
cleanup_resources
