#!/usr/bin/env bash

############################################
# CLUSTERING HELPERS
############################################
# - set_vars
# - cluster_config
# - broker_config
# - broker_xml_config
############################################


############################################
# 1. VARIABLE INITIALIZATION & DERIVATION
############################################
# Determines instance identity, cluster role,
# and filesystem paths used by clustering
############################################

set_vars() {
  # Instance identity
  if [[ -z "${INSTANCE_STRING}" && -n "${HOSTNAME}" ]]; then
    INSTANCE_STRING="${HOSTNAME}"
  fi

  # Backward compatibility
  if [[ -z "${RANDOMSTRING}" ]]; then
    RANDOM_STRING="${INSTANCE_STRING}"
  else
    RANDOM_STRING="${RANDOMSTRING}"
  fi

  INSTANCE_STRING="${RANDOM_STRING}"

  # Cluster role
  if [[ "${EMBEDDED_BROKER}" == "disabled" ]]; then
    CLUSTER_NAME="node"
  else
    CLUSTER_NAME="master"
  fi

  # Derived paths
  CLUSTER_CONFIG_DIR="${GEOSERVER_DATA_DIR}/cluster/${CLUSTER_NAME}/instance_${RANDOM_STRING}"
  MONITOR_AUDIT_PATH="${GEOSERVER_DATA_DIR}/monitoring/monitor_${RANDOM_STRING}"
}

############################################
# 2. CLUSTER CONFIG FILE GENERATORS (JMS)
############################################
# GeoServer JMS clustering configuration
# https://docs.geoserver.org/stable/en/user/community/jms-cluster/
############################################

cluster_config() {
  rm -f "${CLUSTER_CONFIG_DIR}/cluster.properties"

  if [[ ! -f "${CLUSTER_CONFIG_DIR}/cluster.properties" ]]; then
    if [[ -f "${EXTRA_CONFIG_DIR}/cluster.properties" ]]; then
      envsubst < "${EXTRA_CONFIG_DIR}/cluster.properties" \
        > "${CLUSTER_CONFIG_DIR}/cluster.properties"
    else
      envsubst < /build_data/cluster.properties \
        > "${CLUSTER_CONFIG_DIR}/cluster.properties"
    fi
  fi

  [[ -d "${CLUSTER_CONFIG_DIR}" ]] &&
    chown -R "${USER_NAME}:${GEO_GROUP_NAME}" "${CLUSTER_CONFIG_DIR}"
}

broker_config() {
  rm -f "${CLUSTER_CONFIG_DIR}/embedded-broker.properties"

  if [[ ! -f "${CLUSTER_CONFIG_DIR}/embedded-broker.properties" ]]; then
    if [[ -f "${EXTRA_CONFIG_DIR}/embedded-broker.properties" ]]; then
      envsubst < "${EXTRA_CONFIG_DIR}/embedded-broker.properties" \
        > "${CLUSTER_CONFIG_DIR}/embedded-broker.properties"
    else
      envsubst < /build_data/embedded-broker.properties \
        > "${CLUSTER_CONFIG_DIR}/embedded-broker.properties"
    fi
  fi
}

broker_xml_config() {
  rm -f "${CLUSTER_CONFIG_DIR}/broker.xml"

  if [[ ! -f "${CLUSTER_CONFIG_DIR}/broker.xml" ]]; then
    if [[ -f "${EXTRA_CONFIG_DIR}/broker.xml" ]]; then
      envsubst < "${EXTRA_CONFIG_DIR}/broker.xml" \
        > "${CLUSTER_CONFIG_DIR}/broker.xml"
    else
      envsubst < /build_data/broker.xml \
        > "${CLUSTER_CONFIG_DIR}/broker.xml"

      if [[ "${DB_BACKEND}" =~ [Pp][Oo][Ss][Tt][Gg][Rr][Ee][Ss] ]]; then
        sed -i '15,17d' "${CLUSTER_CONFIG_DIR}/broker.xml"
      else
        sed -i '19,37d' "${CLUSTER_CONFIG_DIR}/broker.xml"
      fi
    fi
  fi
}

############################################
# 3. HAZELCAST CLUSTER SUPPORT
############################################

setup_hz_cluster() {
  [[ "${ext}" != "hz-cluster-plugin" ]] && return

  create_dir "${GEOSERVER_DATA_DIR}/cluster"

  if [[ -f "${EXTRA_CONFIG_DIR}/hazelcast_cluster.properties" ]]; then
    envsubst < "${EXTRA_CONFIG_DIR}/hazelcast_cluster.properties" \
      > "${GEOSERVER_DATA_DIR}/cluster/cluster.properties"
  else
    envsubst < /build_data/hazelcast_cluster/cluster.properties \
      > "${GEOSERVER_DATA_DIR}/cluster/cluster.properties"
  fi

  if [[ -f "${EXTRA_CONFIG_DIR}/hazelcast.xml" ]]; then
    envsubst < "${EXTRA_CONFIG_DIR}/hazelcast.xml" \
      > "${GEOSERVER_DATA_DIR}/cluster/hazelcast.xml"
  else
    envsubst < /build_data/hazelcast_cluster/hazelcast.xml \
      > "${GEOSERVER_DATA_DIR}/cluster/hazelcast.xml"
  fi
}

############################################
# 4. CLUSTER ENV EXPORTS & STATE SETUP
############################################

export_cluster_variables() {
  set_vars

  export READONLY CLUSTER_DURABILITY BROKER_URL EMBEDDED_BROKER
  export TOGGLE_MASTER TOGGLE_SLAVE
  export CLUSTER_CONFIG_DIR MONITOR_AUDIT_PATH
  export INSTANCE_STRING
  export CLUSTER_CONNECTION_RETRY_COUNT CLUSTER_CONNECTION_MAX_WAIT

  log "CLUSTER_CONFIG_DIR=${CLUSTER_CONFIG_DIR}"
  log "MONITOR_AUDIT_PATH=${MONITOR_AUDIT_PATH}"
}

setup_cluster() {
  set_vars

  export READONLY CLUSTER_DURABILITY BROKER_URL EMBEDDED_BROKER
  export TOGGLE_MASTER TOGGLE_SLAVE
  export CLUSTER_CONFIG_DIR MONITOR_AUDIT_PATH INSTANCE_STRING

  # Cleanup monitoring logs if clustering disabled
  if [[ "${CLUSTERING}" =~ [Ff][Aa][Ll][Ss][Ee] ]] &&
     [[ "${RESET_MONITORING_LOGS}" =~ [Tt][Rr][Uu][Ee] ]] &&
     [[ -d "${GEOSERVER_DATA_DIR}/monitoring" ]]; then
    find "${GEOSERVER_DATA_DIR}/monitoring" \
      -type d -name 'monitor_*' -exec rm -r {} +
  fi
}

############################################
# 5. MAIN CLUSTERING SETUP FLOW
############################################

setup_clustering_status() {
  [[ "${CLUSTERING}" =~ [Ff][Aa][Ll][Ss][Ee] ]] && return

  ext="jms-cluster-plugin"

  # Ensure clustering extension
  if [[ "${FORCE_DOWNLOAD_COMMUNITY_EXTENSIONS}" =~ [Tt][Rr][Uu][Ee] ]]; then
    rm -f "/community_plugins/${ext}.zip"
  fi

  if [[ ! -f "/community_plugins/${ext}.zip" ]]; then
    community_plugins_url="https://build.geoserver.org/geoserver/${GS_VERSION:0:5}x/community-latest/geoserver-${GS_VERSION:0:4}-SNAPSHOT-${ext}.zip"
    download_extension "${community_plugins_url}" "${ext}" /community_plugins
  fi

  install_plugin /community_plugins "${ext}"

  if [[ -z "${EXISTING_DATA_DIR}" ]]; then
    create_dir "${CLUSTER_CONFIG_DIR}"
    chown -R "${USER_NAME}:${GEO_GROUP_NAME}" "${CLUSTER_CONFIG_DIR}"

    if [[ "${DB_BACKEND}" =~ [Pp][Oo][Ss][Tt][Gg][Rr][Ee][Ss] ]]; then
      postgres_ssl_setup
      export SSL_PARAMETERS="${PARAMS}"
    fi

    broker_xml_config
    cluster_config
    broker_config
  else
    # Validate existing cluster config
    local count
    count=$(find "${CLUSTER_CONFIG_DIR}" \
      -type f \( -name cluster.properties \
               -o -name embedded-broker.properties \
               -o -name broker.xml \) | wc -l)

    [[ "${count}" -ne 3 ]] && {
      echo "Missing cluster configuration files in ${CLUSTER_CONFIG_DIR}"
      exit 1
    }
  fi

  # Temporary fix: jdom2
  cp /build_data/jdom2-2.0.6.1.jar \
    "${CATALINA_HOME}/webapps/${GEOSERVER_CONTEXT_ROOT}/WEB-INF/lib/"
}

############################################
# 6. EXTERNAL / CROSS-FILE DEPENDENCIES
############################################
# These functions are USED here but DEFINED elsewhere.
# Keep here as a reference to decide ownership.
############################################
#
# From filesystem / utils libs:
#   - create_dir
#   - log
#
# From plugin management:
#   - download_extension
#   - install_plugin
#
# From database / SSL:
#   - postgres_ssl_setup
#
#
# From global env:
#   - USER_NAME
#   - GEO_GROUP_NAME
#   - GEOSERVER_DATA_DIR
#   - EXTRA_CONFIG_DIR
#   - DB_BACKEND
#   - GS_VERSION
#   - GEOSERVER_CONTEXT_ROOT
#
############################################
