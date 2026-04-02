#!/usr/bin/env bash
# Download geoserver extensions and other resources

source /scripts/env-data.sh
source /scripts/functions.sh

resources_dir="/tmp/resources"
GS_VERSION=$(cat /scripts/geoserver_version.txt)

create_setup_directories

# Download geoserver and install it
install_geoserver_core

install_plugin_libjpegturbo

install_required_jars

# Overlay files and directories in resources/overlays if they exist
apply_overlays

# Package tomcat webapps - useful to activate later
package_tomcat_webapp


patch_tomcat_server_info

# Setting restrictive umask container-wide
set_restrictive_umask

cleanup_resources