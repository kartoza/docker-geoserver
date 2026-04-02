#!/bin/bash
set -e


figlet -t "Kartoza Docker GeoServer"

# Import env and functions
source /scripts/functions.sh
source /scripts/env-data.sh

# Gosu preparations
setup_geoserver_users

# Create directories
create_entrypoint_directories

# Rename to match wanted context-root and so that we can unzip plugins to
# existing directory.

rename_geoserver_context_root

# Credits https://github.com/kartoza/docker-geoserver/pull/371
set_vars
export  READONLY CLUSTER_DURABILITY BROKER_URL EMBEDDED_BROKER TOGGLE_MASTER TOGGLE_SLAVE BROKER_URL
export CLUSTER_CONFIG_DIR MONITOR_AUDIT_PATH INSTANCE_STRING  CLUSTER_CONNECTION_RETRY_COUNT CLUSTER_CONNECTION_MAX_WAIT


run_pre_start_hooks


log CLUSTER_CONFIG_DIR="${CLUSTER_CONFIG_DIR}"
log MONITOR_AUDIT_PATH="${MONITOR_AUDIT_PATH}"

configure_jvm
configure_telemetry

# Chown again - seems to fix issue with resolving all created directories
fix_permissions

start_geoserver_service


