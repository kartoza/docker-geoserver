#!/usr/bin/env bash


############################################
# 1. VARIABLE INITIALIZATION & DERIVATION
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
            cat > "${CLUSTER_CONFIG_DIR}/cluster.properties" <<EOF
CLUSTER_CONFIG_DIR=${CLUSTER_CONFIG_DIR}
instanceName=${INSTANCE_STRING}
readOnly=${READONLY}
durable=${CLUSTER_DURABILITY}
brokerURL=failover:(${BROKER_URL})
embeddedBroker=${EMBEDDED_BROKER}
connection.retry=${CLUSTER_CONNECTION_RETRY_COUNT}
toggleMaster=${TOGGLE_MASTER}
xbeanURL=./broker.xml
embeddedBrokerProperties=embedded-broker.properties
topicName=VirtualTopic.geoserver
connection=enabled
toggleSlave=${TOGGLE_SLAVE}
connection.maxwait=${CLUSTER_CONNECTION_MAX_WAIT}
group=geoserver-cluster
EOF
    fi
  fi

  [[ "$(id -u)" -eq 0 && -d "${CLUSTER_CONFIG_DIR}" ]] &&
    chown -R "${USER_NAME}:${GEO_GROUP_NAME}" "${CLUSTER_CONFIG_DIR}"
}

broker_config() {
  rm -f "${CLUSTER_CONFIG_DIR}/embedded-broker.properties"

  if [[ ! -f "${CLUSTER_CONFIG_DIR}/embedded-broker.properties" ]]; then
    if [[ -f "${EXTRA_CONFIG_DIR}/embedded-broker.properties" ]]; then
      envsubst < "${EXTRA_CONFIG_DIR}/embedded-broker.properties" \
        > "${CLUSTER_CONFIG_DIR}/embedded-broker.properties"
    else
          cat > "${CLUSTER_CONFIG_DIR}/embedded-broker.properties" <<EOF
activemq.jmx.useJmx=false
activemq.jmx.port=1098
activemq.jmx.host=localhost
activemq.jmx.createConnector=false
activemq.transportConnectors.server.uri=${BROKER_URL}?maximumConnections=1000&wireFormat.maxFrameSize=104857600&jms.useAsyncSend=true&transport.daemon=true&trace=true
activemq.transportConnectors.server.discoveryURI=multicast://default
activemq.broker.persistent=true
activemq.base=./
activemq.broker.systemUsage.memoryUsage=128 mb
activemq.broker.systemUsage.storeUsage=1 gb
activemq.broker.systemUsage.tempUsage=128 mb
EOF
    fi
  fi
}

broker_xml_config() {
  local target="${CLUSTER_CONFIG_DIR}/broker.xml"

  # Always remove old broker.xml
  rm -f "$target"

  # Helper: write default broker.xml
  write_default_broker_xml() {
    cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:amq="http://activemq.apache.org/schema/core"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans-2.0.xsd
                           http://activemq.apache.org/schema/core http://activemq.apache.org/schema/core/activemq-core.xsd">
  <bean class="org.springframework.beans.factory.config.PropertyPlaceholderConfigurer"/>

  <broker id="broker" persistent="${activemq.broker.persistent}"
          useJmx="true" xmlns="http://activemq.apache.org/schema/core"
          dataDirectory="${activemq.base}" tmpDataDirectory="${activemq.base}/tmp"
          startAsync="false" start="false" brokerName="${INSTANCE_STRING}">

    <amq:persistenceAdapter>
      <jdbcPersistenceAdapter dataDirectory="activemq-data"
                              dataSource="#postgres-ds" lockKeepAlivePeriod="0"
                              createTablesOnStartup="true"
                              brokerName="${INSTANCE_STRING}"/>
      <statements useLockCreateWhereClause="true"
                  tablePrefix="ACTIVEMQ_"
                  dualCommitEnabled="false"
                  updateClob="true"
                  updateBlob="true"
                  lockKeepAlivePeriod="30000"/>
    </amq:persistenceAdapter>

    <bean id="postgres-ds" class="org.postgresql.ds.PGPoolingDataSource">
      <property name="url" value="jdbc:postgresql://${HOST}:${POSTGRES_PORT}/${POSTGRES_DB}?${SSL_PARAMETERS}"/>
      <property name="user" value="${POSTGRES_USER}"/>
      <property name="password" value="${POSTGRES_PASS}"/>
      <property name="initialConnections" value="15"/>
      <property name="maxConnections" value="30"/>
    </bean>

    <networkConnectors xmlns="http://activemq.apache.org/schema/core">
      <networkConnector uri="static:(tcp://host1:61616,tcp://host2:61616,tcp://host3:61616,tcp://localhost:61616)" />
    </networkConnectors>

    <transportConnectors>
      <transportConnector name="openwire" uri="${activemq.transportConnectors.server.uri}" />
    </transportConnectors>
  </broker>
</beans>
EOF
  }

  # Step 1: generate broker.xml
  if [[ -f "${EXTRA_CONFIG_DIR}/broker.xml" ]]; then
    envsubst < "${EXTRA_CONFIG_DIR}/broker.xml" > "$target"
  else
    write_default_broker_xml > "$target"
  fi

  # Step 2: post-process broker.xml depending on DB_BACKEND
  adjust_broker_xml() {
    case "$DB_BACKEND" in
      [Pp][Oo][Ss][Tt][Gg][Rr][Ee][Ss])
        sed -i '15,17d' "$target"
        ;;
      *)
        sed -i '19,37d' "$target"
        ;;
    esac
  }

  adjust_broker_xml
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
    if [[ "$(id -u)" -eq 0 ]]; then
      chown -R "${USER_NAME}:${GEO_GROUP_NAME}" "${CLUSTER_CONFIG_DIR}"
    fi

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


}

