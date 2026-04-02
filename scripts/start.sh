#!/bin/bash

source /scripts/functions.sh
source /scripts/env-data.sh
GS_VERSION=$(cat /scripts/geoserver_version.txt)
STABLE_PLUGIN_BASE_URL=$(cat /scripts/geoserver_gs_url.txt)

web_cors
# Useful for development - We need a clean state of data directory
cleanup_data_dir

# install Font files in resources/fonts if they exists
install_fonts
install_sample_data


# Install google fonts based on https://github.com/google/fonts
setup_google_fonts

setup_logging

# Add custom espg properties file or the default one
setup_crs

# Activate sample data
install_sample_data

# Recreate DISK QUOTA config, useful to change between H2 and jdbc and change connection or schema
reset_disk_quota
setup_disk_quota

# GWC Global Config options GeoServer WMS
setup_gwc_status

sync_gdal_version
# Default installed extensions
setup_extensions
setup_s3_extension
setup_community_extensions_status

# Setup clustering
setup_cluster

setup_monitoring_status

setup_clustering_status

# Setup control flow properties
setup_control_flow

setup_geoserver_logging


setup_jndi_status


setup_tomcat_webapp_status

# Enable SSL
setup_tomcat_ssl_status

#Unset env variables
clean_up_vars


run_update_password_hook /scripts/update_passwords.sh

# Run some extra bash script to fix issues i.e missing dependencies in lib caused by community extensions
entry_point_script

log4j_logging

