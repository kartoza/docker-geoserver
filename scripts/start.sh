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

GS_VERSION=$(cat /scripts/geoserver_version.txt)
STABLE_PLUGIN_BASE_URL=$(cat /scripts/geoserver_gs_url.txt)
create_dir "${GEOWEBCACHE_CACHE_DIR}"

#############################################
# Functions
#############################################

web_cors
# Useful for development - We need a clean state of data directory
cleanup_data_dir
install_fonts
setup_google_fonts
setup_logging
setup_crs
# Activate sample data
install_sample_data
# Recreate DISK QUOTA config, useful to change between H2 and jdbc and change connection or schema
reset_disk_quota
setup_disk_quota
setup_gwc_status
# Default installed extensions
setup_extensions
sync_gdal_version
setup_s3_extension
setup_community_extensions_status


# Setup clustering
setup_cluster
setup_monitoring_status
setup_clustering_status
setup_control_flow_status
setup_geoserver_logging_status
setup_jndi_status
setup_tomcat_webapp_status
setup_tomcat_ssl_status
clean_up_vars
run_update_password_hook
entry_point_script
log4j_logging

