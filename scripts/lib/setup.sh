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
source "${SCRIPT_DIR}/lib/extensions.sh"

resources_dir="/tmp/resources"
GS_VERSION=$(grep '^GEOSERVER_VERSION=' /etc/kartoza/build_info.env | cut -d= -f2-)
STABLE_PLUGIN_BASE_URL=$(grep '^STABLE_PLUGIN_URL=' /etc/kartoza/build_info.env | cut -d= -f2-)

# ---------------------------
# Main execution flow
# ---------------------------

create_setup_directories
install_geoserver_core
install_plugin_libjpegturbo
install_required_jars
apply_overlays
package_tomcat_webapp
patch_tomcat_server_info
set_restrictive_umask
cleanup_resources