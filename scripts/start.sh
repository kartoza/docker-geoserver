#!/bin/bash

#############################################
# Bootstrap
#############################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/lib/env-data.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/logging.sh"
source "${SCRIPT_DIR}/lib/database.sh"
source "${SCRIPT_DIR}/lib/geoserver.sh"
source "${SCRIPT_DIR}/lib/tomcat.sh"
source "${SCRIPT_DIR}/lib/cluster.sh"
source "${SCRIPT_DIR}/lib/extensions.sh"

GS_VERSION=$(cat /scripts/geoserver_version.txt)
STABLE_PLUGIN_BASE_URL=$(cat /scripts/geoserver_gs_url.txt)

#############################################
# Functions
#############################################

web_cors
cleanup_data_dir
install_fonts
install_sample_data
setup_logging_status
setup_crs_status
install_sample_data
reset_disk_quota
setup_disk_quota_status
setup_gwc_status
sync_gdal_version
setup_extensions
setup_s3_extension
setup_community_extensions_status
setup_cluster
setup_monitoring_status
setup_clustering_status
setup_control_flow_status
setup_geoserver_logging
setup_jndi_status
setup_tomcat_webapp_status
setup_tomcat_ssl_status
clean_up_vars
run_update_password_hook
entry_point_script
log4j_logging

