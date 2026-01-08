#!/usr/bin/env bash

############################################
# Helper functions containing
# cluster_config
# broker_config
# broker_xml_config
############################################

# Credits to https://github.com/korkin25 from https://github.com/kartoza/docker-geoserver/pull/371
set_vars() {
  if [ -z "${INSTANCE_STRING}" ];then
    if [ ! -z "${HOSTNAME}" ]; then
      INSTANCE_STRING="${HOSTNAME}"
    fi
  fi

  # Backward compatability
  if [[ -z ${RANDOMSTRING} ]];then
    RANDOM_STRING="${INSTANCE_STRING}"
  else
    RANDOM_STRING=${RANDOMSTRING}
  fi

  INSTANCE_STRING="${RANDOM_STRING}"
  if [[ ${EMBEDDED_BROKER} == 'disabled' ]];then
    CLUSTER_NAME=node
  else
    CLUSTER_NAME=master
  fi
  CLUSTER_CONFIG_DIR="${GEOSERVER_DATA_DIR}/cluster/${CLUSTER_NAME}/instance_${RANDOM_STRING}"
  MONITOR_AUDIT_PATH="${GEOSERVER_DATA_DIR}/monitoring/monitor_${RANDOM_STRING}"
}


# Helper function to setup cluster config for the clustering plugin
# https://docs.geoserver.org/stable/en/user/community/jms-cluster/index.html
cluster_config() {
  # Remove default config
  if [ -f "${CLUSTER_CONFIG_DIR}"/cluster.properties ];then
    rm "${CLUSTER_CONFIG_DIR}"/cluster.properties
  fi
  if [[ ! -f ${CLUSTER_CONFIG_DIR}/cluster.properties ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/cluster.properties ]]; then
      envsubst < "${EXTRA_CONFIG_DIR}"/cluster.properties > "${CLUSTER_CONFIG_DIR}"/cluster.properties
    else
      # default values
      envsubst < /build_data/cluster.properties > "${CLUSTER_CONFIG_DIR}"/cluster.properties
    fi
  fi
  if [[ -d "${CLUSTER_CONFIG_DIR}" ]];then
    chown -R "${USER_NAME}":"${GEO_GROUP_NAME}" "${CLUSTER_CONFIG_DIR}"
  fi
}

# Helper function to setup broker config. Used with clustering configs
# https://docs.geoserver.org/stable/en/user/community/jms-cluster/index.html


broker_config() {
  # Delete default config
  if [ -f "${CLUSTER_CONFIG_DIR}"/embedded-broker.properties ];then
    rm "${CLUSTER_CONFIG_DIR}"/embedded-broker.properties
  fi

  if [[ ! -f ${CLUSTER_CONFIG_DIR}/embedded-broker.properties ]]; then
    # If it doesn't exists, copy from /settings directory if exists

      if [[ -f ${EXTRA_CONFIG_DIR}/embedded-broker.properties ]]; then
        envsubst < "${EXTRA_CONFIG_DIR}"/embedded-broker.properties > "${CLUSTER_CONFIG_DIR}"/embedded-broker.properties
      else
        # default values
        envsubst < /build_data/embedded-broker.properties > "${CLUSTER_CONFIG_DIR}"/embedded-broker.properties
      fi



  fi
}

broker_xml_config() {
  # Delete default config
  if [ -f "${CLUSTER_CONFIG_DIR}"/broker.xml ];then
    rm "${CLUSTER_CONFIG_DIR}"/broker.xml
  fi
  if [[ ! -f ${CLUSTER_CONFIG_DIR}/broker.xml ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/broker.xml ]]; then
      envsubst < "${EXTRA_CONFIG_DIR}"/broker.xml > "${CLUSTER_CONFIG_DIR}"/broker.xml
    else
      # default values
      if [[  ${DB_BACKEND} =~ [Pp][Oo][Ss][Tt][Gg][Rr][Ee][Ss] ]]; then
        envsubst < /build_data/broker.xml > "${CLUSTER_CONFIG_DIR}"/broker.xml
        sed -i -e '15,17d' "${CLUSTER_CONFIG_DIR}"/broker.xml
      else
        envsubst < /build_data/broker.xml > "${CLUSTER_CONFIG_DIR}"/broker.xml
        sed -i -e '19,37d' "${CLUSTER_CONFIG_DIR}"/broker.xml
      fi
    fi
  fi
}

setup_hz_cluster() {
  # TODO Add http://og.cens.am:8081/opengeo-docs/sysadmin/clustering/setup.html#session-sharing
  if [[ ${ext} == 'hz-cluster-plugin' ]];then
      create_dir "${GEOSERVER_DATA_DIR}"/cluster
      if [[ -f "${EXTRA_CONFIG_DIR}"/hazelcast_cluster.properties ]]; then
        envsubst < "${EXTRA_CONFIG_DIR}"/hazelcast_cluster.properties > "${GEOSERVER_DATA_DIR}"/cluster/cluster.properties
      else
        envsubst < /build_data/hazelcast_cluster/cluster.properties > "${GEOSERVER_DATA_DIR}"/cluster/cluster.properties
      fi
      if [[ -f "${EXTRA_CONFIG_DIR}"/hazelcast.xml ]]; then
        envsubst < "${EXTRA_CONFIG_DIR}"/hazelcast.xml > "${GEOSERVER_DATA_DIR}"/cluster/hazelcast.xml
      else
        envsubst < /build_data/hazelcast_cluster/hazelcast.xml > "${GEOSERVER_DATA_DIR}"/cluster/hazelcast.xml
      fi
  fi
}