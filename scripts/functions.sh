#!/usr/bin/env bash

function log() {
    echo "$0:${BASH_LINENO[*]}": $@
}

generate_random_string() {
  local length="$1"
  local file="${EXTRA_CONFIG_DIR}/.pass_${length}.txt"

  [[ -f "${file}" ]] || tr -dc '[:alnum:]' </dev/urandom | head -c "${length}" > "${file}"
  RAND="$(<"${file}")"
  export RAND
}


create_dir() {
  local DATA_PATH="$1"

  if [[ -z "${DATA_PATH}" ]]; then
    echo -e "\e[31m [ERROR] create_dir: No path provided \033[0m" >&2
    return 1
  fi

  if [[ ! -d "${DATA_PATH}" ]]; then
    if ! mkdir -p "${DATA_PATH}"; then
      echo -e "\e[31m [ERROR] Failed to create directory: ${DATA_PATH} \033[0m" >&2
      return 1
    fi
  fi
}


delete_file() {
  [[ -f "$1" ]] && rm "$1"
}

delete_folder() {
  [[ -d "$1" ]] && rm -r "$1"
}



# Function to add custom crs in geoserver data directory
# https://docs.geoserver.org/latest/en/user/configuration/crshandling/customcrs.html
setup_custom_crs() {
  if [[ -f "${EXTRA_CONFIG_DIR}/epsg.properties" ]]; then
    cp -f "${EXTRA_CONFIG_DIR}/epsg.properties" \
          "${GEOSERVER_DATA_DIR}/user_projections/"
  elif [[ ! -f "${GEOSERVER_DATA_DIR}/user_projections/epsg.properties" ]]; then
    cp -f "${CATALINA_HOME}/data/user_projections/epsg.properties" \
          "${GEOSERVER_DATA_DIR}/user_projections/epsg.properties"
  fi
}


setup_custom_override_crs() {
  [[ -f "${EXTRA_CONFIG_DIR}/epsg_overrides.properties" ]] &&
    cp -f "${EXTRA_CONFIG_DIR}/epsg_overrides.properties" \
          "${GEOSERVER_DATA_DIR}/user_projections/"
}


setup_crs() {
  create_dir "${GEOWEBCACHE_CACHE_DIR}"
  create_dir "${GEOSERVER_DATA_DIR}/user_projections"
  setup_custom_crs
  setup_custom_override_crs
}

# Function to enable cors support thought tomcat
# https://documentation.bonitasoft.com/bonita/2021.1/enable-cors-in-tomcat-bundle
web_cors() {
  local web_xml="${CATALINA_HOME}/conf/web.xml"
  local custom_web_xml="${EXTRA_CONFIG_DIR}/web.xml"
  if [[ ! -f "${web_xml}" ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f "${custom_web_xml}"  ]]; then
      cp -f "${custom_web_xml}"  "${CATALINA_HOME}"/conf/
    else
      # default values
      envsubst < /build_data/web.xml > "${web_xml}"
      ###
      # Deactivate CORS filter in web.xml if DISABLE_CORS=true
      # Useful if CORS is handled outside of Tomcat (e.g. in a proxying webserver like nginx)
      ###
      if [[ "${DISABLE_CORS}" =~ [Tt][Rr][Uu][Ee] ]]; then
        sed -i 's/<!-- CORS_START.*/<!-- CORS DEACTIVATED BY DISABLE_CORS -->\n<!--/; s/^.*<!-- CORS_END -->/-->/' \
          "${web_xml}"
      fi
      ###
      # Deactivate security filter in web.xml if DISABLE_SECURITY_FILTER=true
      # https://github.com/kartoza/docker-geoserver/issues/549
      ###
      if [[ "${DISABLE_SECURITY_FILTER}" =~ [Tt][Rr][Uu][Ee] ]]; then
        sed -i 's/<!-- SECURITY_START.*/<!-- SECURITY FILTER DEACTIVATED BY DISABLE_SECURITY_FILTER -->\n<!--/; s/^.*<!-- SECURITY_END -->/-->/' \
          "${web_xml}"
      fi
    fi
  fi
}

# Function to add users when tomcat manager is configured
# https://tomcat.apache.org/tomcat-8.0-doc/manager-howto.html

tomcat_user_config() {
  [[ -f "${CATALINA_HOME}/conf/tomcat-users.xml" ]] && return

  if [[ -f "${EXTRA_CONFIG_DIR}/tomcat-users.xml" ]]; then
    envsubst < "${EXTRA_CONFIG_DIR}/tomcat-users.xml" \
      > "${CATALINA_HOME}/conf/tomcat-users.xml"
  else
    envsubst < /build_data/tomcat-users.xml \
      > "${CATALINA_HOME}/conf/tomcat-users.xml"
  fi
}

# Helper function to download extensions
download_extension() {
  curl --progress-bar -fL \
    -o "$3/$2.zip" "$1"
}



validate_geo_install() {
  [[ -d "$1" && "$(ls -A "$1")" ]] || {
    echo "GeoServer install dir missing, exiting"
    exit 1
  }
}

detect_install_dir() {
  [[ -f "${GEOSERVER_HOME}/start.jar" ]] && echo "${GEOSERVER_HOME}" || echo "${CATALINA_HOME}"
}

unzip_geoserver() {
  if [[ -f /tmp/geoserver/geoserver.war ]]; then
    unzip /tmp/geoserver/geoserver.war \
      -d "${CATALINA_HOME}/webapps/${GEOSERVER_CONTEXT_ROOT}"

    validate_geo_install "${CATALINA_HOME}/webapps/${GEOSERVER_CONTEXT_ROOT}"

    cp -r "${CATALINA_HOME}/webapps/${GEOSERVER_CONTEXT_ROOT}/data" "${CATALINA_HOME}"
    mv "${CATALINA_HOME}/data/security" "${CATALINA_HOME}"
    rm -rf "${CATALINA_HOME}/webapps/${GEOSERVER_CONTEXT_ROOT}/data"

    if [[ ! -d "${CATALINA_HOME}/postgres_config/" ]];then
      create_dir "${CATALINA_HOME}/postgres_config"
    fi

    mv "${CATALINA_HOME}/webapps/${GEOSERVER_CONTEXT_ROOT}/WEB-INF/lib/postgresql-"* \
       "${CATALINA_HOME}/postgres_config/"
  else
    cp -r /tmp/geoserver/* "${GEOSERVER_HOME}/"
    validate_geo_install "${GEOSERVER_HOME}"
    cp -r "${GEOSERVER_HOME}/data_dir" "${CATALINA_HOME}/data"
    mv "${CATALINA_HOME}/data/security" "${CATALINA_HOME}"
  fi

  rm -rf /tmp/geoserver
}


# A little logic that will fetch the geoserver war zip file if it is not available locally in the resources dir
package_geoserver() {
  if [[ -f "/tmp/resources/geoserver-${GS_VERSION}.zip" ]]; then
    unzip "/tmp/resources/geoserver-${GS_VERSION}.zip" -d /tmp/geoserver
  elif [[ -f "/tmp/resources/geoserver.war" ]]; then
    mkdir -p /tmp/geoserver
    cp /tmp/resources/geoserver.war /tmp/geoserver/
  elif [[ -f "${REQUIRED_PLUGINS_DIR}/geoserver.zip" ]]; then
    unzip "${REQUIRED_PLUGINS_DIR}/geoserver.zip" -d /tmp/geoserver
  elif [[ -f "${REQUIRED_PLUGINS_DIR}/geoserver.war" ]]; then
    mkdir -p /tmp/geoserver
    cp "${REQUIRED_PLUGINS_DIR}/geoserver.war" /tmp/geoserver/
  else
    echo "GeoServer bin/war missing, exiting"
    exit 1
  fi

  unzip_geoserver
}



# Helper function to setup cluster config for the clustering plugin
# https://docs.geoserver.org/stable/en/user/community/jms-cluster/index.html
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

  [[ -d "${CLUSTER_CONFIG_DIR}" ]] &&
    chown -R "${USER_NAME}:${GEO_GROUP_NAME}" "${CLUSTER_CONFIG_DIR}"
}

# Helper function to setup broker config. Used with clustering configs
# https://docs.geoserver.org/stable/en/user/community/jms-cluster/index.html


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


s3_config() {
  cat >"${GEOSERVER_DATA_DIR}"/s3.properties <<EOF
${S3_ALIAS}.s3.endpoint=${S3_SERVER_URL}
${S3_ALIAS}.s3.user=${S3_USERNAME}
${S3_ALIAS}.s3.password=${S3_PASSWORD}
EOF

}

# Helper function to configure s3 bucket
# https://docs.geoserver.org/latest/en/user/community/s3-geotiff/index.html
# Remove this based on https://www.mail-archive.com/geoserver-users@lists.sourceforge.net/msg34214.html

# Helper function to install plugin in proper path

install_plugin() {
  local data_path="${1:-/community_plugins}"
  local ext="$2"

  [[ -f "${data_path}/${ext}.zip" ]] || return

  unzip -qq "${data_path}/${ext}.zip" -d /tmp/gs_plugin
  GEOSERVER_INSTALL_DIR="$(detect_install_dir)"

  cp -u /tmp/gs_plugin/*.jar \
     "${GEOSERVER_INSTALL_DIR}/webapps/${GEOSERVER_CONTEXT_ROOT}/WEB-INF/lib/"

  rm -rf /tmp/gs_plugin
}


# Helper function to setup disk quota configs and database configurations

default_disk_quota_config() {
  [[ -f "${GEOWEBCACHE_CACHE_DIR}/geowebcache-diskquota.xml" ]] && return

  if [[ -f "${EXTRA_CONFIG_DIR}/geowebcache-diskquota.xml" ]]; then
    envsubst < "${EXTRA_CONFIG_DIR}/geowebcache-diskquota.xml" \
      > "${GEOWEBCACHE_CACHE_DIR}/geowebcache-diskquota.xml"
  else
    cat > "${GEOWEBCACHE_CACHE_DIR}/geowebcache-diskquota.xml" <<EOF
<gwcQuotaConfiguration>
  <enabled>true</enabled>
  <cacheCleanUpFrequency>${DISK_QUOTA_FREQUENCY}</cacheCleanUpFrequency>
  <cacheCleanUpUnits>SECONDS</cacheCleanUpUnits>
  <maxConcurrentCleanUps>2</maxConcurrentCleanUps>
  <globalExpirationPolicyName>LFU</globalExpirationPolicyName>
  <globalQuota>
    <value>${DISK_QUOTA_SIZE}</value>
    <units>GiB</units>
  </globalQuota>
 <quotaStore>${DISK_QUOTA_BACKEND}</quotaStore>
</gwcQuotaConfiguration>
EOF

  fi
}

jdbc_disk_quota_config() {
  if [[ ! -f "${GEOWEBCACHE_CACHE_DIR}"/geowebcache-diskquota-jdbc.xml ]]; then
    if [[ -f "${EXTRA_CONFIG_DIR}/geowebcache-diskquota-jdbc.xml" ]]; then
      envsubst < "${EXTRA_CONFIG_DIR}/geowebcache-diskquota-jdbc.xml" \
        > "${GEOWEBCACHE_CACHE_DIR}/geowebcache-diskquota-jdbc.xml"
    else
      cat > "${GEOWEBCACHE_CACHE_DIR}/geowebcache-diskquota-jdbc.xml" <<EOF
<gwcJdbcConfiguration>
  <dialect>PostgreSQL</dialect>
  <connectionPool>
    <driver>org.postgresql.Driver</driver>
    <url>jdbc:postgresql://${HOST}:${POSTGRES_PORT}/${POSTGRES_DB}?${SSL_PARAMETERS}&amp;currentSchema=${POSTGRES_SCHEMA}</url>
    <username>${POSTGRES_USER}</username>
    <password>${POSTGRES_PASS}</password>
    <minConnections>1</minConnections>
    <maxConnections>100</maxConnections>
    <connectionTimeout>10000</connectionTimeout>
    <maxOpenPreparedStatements>50</maxOpenPreparedStatements>
  </connectionPool>
</gwcJdbcConfiguration>
EOF
    fi
  fi
}

setup_disk_quota() {
  export DISK_QUOTA_FREQUENCY DISK_QUOTA_SIZE

  if [[ "${DB_BACKEND}" =~ [Pp][Oo][Ss][Tt][Gg][Rr][Ee][Ss] ]]; then
    postgres_ssl_setup
    export DISK_QUOTA_BACKEND=JDBC
    export SSL_PARAMETERS="${PARAMS}"

    default_disk_quota_config
    jdbc_disk_quota_config

    if [[ "${POSTGRES_SCHEMA}" != "public" ]]; then
      export PGPASSWORD="${POSTGRES_PASS}"
      postgres_ready_status "${HOST}" "${POSTGRES_PORT}" "${POSTGRES_USER}" "${POSTGRES_DB}"
      create_gwc_tile_tables \
        "${HOST}" "${POSTGRES_PORT}" "${POSTGRES_USER}" \
        "${POSTGRES_DB}" "${POSTGRES_SCHEMA}"
    fi
  else
    export DISK_QUOTA_BACKEND=HSQL
    default_disk_quota_config
  fi
}

reset_disk_quota() {
  [[ "${RECREATE_DISKQUOTA}" =~ [Tt][Rr][Uu][Ee] ]] || return

  rm -f \
    "${GEOWEBCACHE_CACHE_DIR}/geowebcache-diskquota.xml" \
    "${GEOWEBCACHE_CACHE_DIR}/geowebcache-diskquota-jdbc.xml"
}

activate_gwc_global_configs() {
  if [[ ! -f "${GEOSERVER_DATA_DIR}"/gwc-gs.xml ]]; then
    if [[ -f "${EXTRA_CONFIG_DIR}"/gwc-gs.xml ]]; then
      envsubst < "${EXTRA_CONFIG_DIR}"/gwc-gs.xml > "${GEOSERVER_DATA_DIR}"/gwc-gs.xml
    else
      cat > "${GEOSERVER_DATA_DIR}"/gwc-gs.xml <<EOF
<GeoServerGWCConfig>
  <version>1.1.0</version>
  <directWMSIntegrationEnabled>${WMS_DIR_INTEGRATION}</directWMSIntegrationEnabled>
  <requireTiledParameter>${REQUIRE_TILED_PARAMETER}</requireTiledParameter>
  <WMSCEnabled>${WMSC_ENABLED}</WMSCEnabled>
  <TMSEnabled>${TMS_ENABLED}</TMSEnabled>
  <securityEnabled>${SECURITY_ENABLED}</securityEnabled>
  <innerCachingEnabled>false</innerCachingEnabled>
  <persistenceEnabled>true</persistenceEnabled>
  <cacheProviderClass>class org.geowebcache.storage.blobstore.memory.guava.GuavaCacheProvider</cacheProviderClass>
  <cacheConfigurations>
    <entry>
      <string>class org.geowebcache.storage.blobstore.memory.guava.GuavaCacheProvider</string>
      <InnerCacheConfiguration>
        <hardMemoryLimit>16</hardMemoryLimit>
        <policy>NULL</policy>
        <concurrencyLevel>4</concurrencyLevel>
        <evictionTime>120</evictionTime>
      </InnerCacheConfiguration>
    </entry>
  </cacheConfigurations>
  <cacheLayersByDefault>true</cacheLayersByDefault>
  <cacheNonDefaultStyles>true</cacheNonDefaultStyles>
  <metaTilingX>4</metaTilingX>
  <metaTilingY>4</metaTilingY>
  <gutter>0</gutter>
  <defaultCachingGridSetIds>
    <string>WebMercatorQuad</string>
    <string>EPSG:4326</string>
    <string>WebMercatorQuadx2</string>
    <string>EPSG:900913</string>
  </defaultCachingGridSetIds>
  <defaultCoverageCacheFormats>
    <string>image/png</string>
    <string>image/jpeg</string>
  </defaultCoverageCacheFormats>
  <defaultVectorCacheFormats>
    <string>application/vnd.mapbox-vector-tile</string>
    <string>image/png</string>
    <string>image/jpeg</string>
  </defaultVectorCacheFormats>
  <defaultOtherCacheFormats>
    <string>application/vnd.mapbox-vector-tile</string>
    <string>image/png</string>
    <string>image/jpeg</string>
  </defaultOtherCacheFormats>
</GeoServerGWCConfig>
EOF
    fi
  fi
}

setup_gwc_status() {
  export WMS_DIR_INTEGRATION REQUIRE_TILED_PARAMETER WMSC_ENABLED TMS_ENABLED SECURITY_ENABLED
  activate_gwc_global_configs
}

# Function to setup control flow https://docs.geoserver.org/stable/en/user/extensions/controlflow/index.html
setup_control_flow() {
  export REQUEST_TIMEOUT PARALLEL_REQUEST GETMAP REQUEST_EXCEL SINGLE_USER GWC_REQUEST WPS_REQUEST USER_WMS_REQUEST THROTTLE_REQUEST_PER_IP
  if [[ ! -f "${GEOSERVER_DATA_DIR}"/controlflow.properties ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f "${EXTRA_CONFIG_DIR}"/controlflow.properties ]]; then
      envsubst < "${EXTRA_CONFIG_DIR}"/controlflow.properties > "${GEOSERVER_DATA_DIR}"/controlflow.properties
    else
           cat > "${GEOSERVER_DATA_DIR}"/controlflow.properties <<EOF
timeout=${REQUEST_TIMEOUT}
ows.global=${PARALLEL_REQUEST}
ows.wms.getmap=${GETMAP}
ows.wfs.getfeature.application/msexcel=${REQUEST_EXCEL}
user=${SINGLE_USER}
ows.gwc=${GWC_REQUEST}
user.ows.wps.execute=${WPS_REQUEST}
user.ows.wms.getmap=${USER_WMS_REQUEST}
ip=${THROTTLE_REQUEST_PER_IP}
EOF
    fi
  fi

}


log4j_logging() {
  if [[ ! -f "${CATALINA_HOME}/log4j.properties" ]]; then
    if [[ -f "${EXTRA_CONFIG_DIR}/log4j.properties" ]]; then
      envsubst < "${EXTRA_CONFIG_DIR}/log4j.properties" > "${CATALINA_HOME}/log4j.properties"
    else
      if [[ ${CLUSTERING} =~ [Tt][Rr][Uu][Ee] ]]; then
        export LOG_PATH="${CLUSTER_CONFIG_DIR}/geoserver-${HOSTNAME}.log"
      else
        export LOG_PATH="${GEOSERVER_LOG_DIR}/geoserver.log"
      fi
      envsubst < /build_data/log4j.properties > "${CATALINA_HOME}/log4j.properties"
    fi
  fi
}

set_logging_xml() {
  cat > "${GEOSERVER_LOG_SETTINGS_PATH}" <<EOF
<logging>
  <level>${GEOSERVER_LOG_PROFILE}</level>
  <location>${LOG_PATH}</location>
  <stdOutLogging>true</stdOutLogging>
</logging>
EOF
}




geoserver_logging() {
  export GEOSERVER_LOG_SETTINGS_PATH="${GEOSERVER_DATA_DIR}/logging.xml"

  if [[ ${CLUSTERING} =~ [Tt][Rr][Uu][Ee] ]]; then
    export LOG_PATH="${CLUSTER_CONFIG_DIR}/geoserver-${HOSTNAME}.log"
  else
    create_dir "${GEOSERVER_LOG_DIR}"
    export LOG_PATH="${GEOSERVER_LOG_DIR}/geoserver.log"
  fi

  if [[ -z "${GEOSERVER_LOG_PROFILE}" ]]; then
    if [[ -f "${GEOSERVER_LOG_SETTINGS_PATH}" ]]; then
      GEOSERVER_LOG_PROFILE=$(sed -n 's:.*<level>\(.*\)</level>.*:\1:p' "${GEOSERVER_LOG_SETTINGS_PATH}" | head -n 1)
    else
      GEOSERVER_LOG_PROFILE=DEFAULT_LOGGING
    fi
  fi

  set_logging_xml
  [[ -f "${LOG_PATH}" ]] || touch "${LOG_PATH}"
}


setup_geoserver_logging(){
  export GEOSERVER_LOG_PROFILE
  geoserver_logging

}





tomcat_logging() {
  if [[ -f "${EXTRA_CONFIG_DIR}/logging.properties" ]]; then
    envsubst < "${EXTRA_CONFIG_DIR}/logging.properties" > "${CATALINA_HOME}/conf/logging.properties"
  else
    envsubst < /build_data/logging.properties > "${CATALINA_HOME}/conf/logging.properties"
  fi
}

setup_logging() {
  if [[ ${LOGGING_STDOUT} =~ [Tt][Rr][Uu][Ee] ]]; then
    export CONSOLE_HANDLER_LEVEL
    tomcat_logging
  fi
}

# Function to read env variables from secrets
function file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		printf >&2 'error: both %s and %s are set (but are exclusive)\n' "$var" "$fileVar"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}
# Credits to https://github.com/korkin25 from https://github.com/kartoza/docker-geoserver/pull/371
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


postgres_ssl_setup() {
  case "${SSL_MODE}" in
    verify-ca|verify-full)
      export PARAMS="sslmode=${SSL_MODE}&sslcert=${SSL_CERT_FILE}&sslkey=${SSL_KEY_FILE}&sslrootcert=${SSL_CA_FILE}"
      ;;
    *)
      export PARAMS="sslmode=${SSL_MODE}"
      ;;
  esac
}




make_hash() {
  local NEW_PASSWORD="$1"
  local GEO_INSTALL_PATH="$2"
  local ALGO_TYPE="$3"

  local HASH
  HASH=$(java -classpath "$(find "${GEO_INSTALL_PATH}" -regex '.*jasypt-[0-9]\.[0-9]\.[0-9].*jar')" \
    org.jasypt.intf.cli.JasyptStringDigestCLI digest.sh \
    algorithm="${ALGO_TYPE}" saltSizeBytes=16 iterations=100000 input="${NEW_PASSWORD}" verbose=0 \
    2>/dev/null \
    | grep -Eoi '^[A-Za-z0-9+/=]+$' \
    | head -1)

  echo "digest1:${HASH}"
}

postgres_ready_status() {
  until psql -h "$1" -p "$2" -U "$3" -d "$4" -c '\dt' >/dev/null 2>&1; do
    sleep 1
  done
}

create_gwc_tile_tables(){
  HOST="$1"
  PORT="$2"
  USER="$3"
  DB="$4"
  POSTGRES_SCHEMA="$5"
  if [ "${POSTGRES_SCHEMA}" != 'public' ]; then
   psql -d "$DB" -p "$PORT" -U "$USER" -h "$HOST" -c "CREATE SCHEMA IF NOT EXISTS ${POSTGRES_SCHEMA}"
   psql -d "$DB" -p "$PORT" -U "$USER" -h "$HOST" -c "CREATE TABLE IF NOT EXISTS ${POSTGRES_SCHEMA}.tileset(key character varying(320) NOT NULL,layer_name character varying(128),gridset_id character varying(32) ,blob_format character varying(64) ,parameters_id character varying(41) ,bytes numeric(21,0) NOT NULL DEFAULT 0,CONSTRAINT tileset_pkey PRIMARY KEY (key))"
   psql -d "$DB" -p "$PORT" -U "$USER" -h "$HOST" -c "CREATE TABLE IF NOT EXISTS $POSTGRES_SCHEMA.tilepage(key character varying(320) NOT NULL,tileset_id character varying(320),page_z smallint,page_x integer,page_y integer,creation_time_minutes integer,frequency_of_use double precision,last_access_time_minutes integer,fill_factor double precision,num_hits numeric(64,0),CONSTRAINT tilepage_pkey PRIMARY KEY (key),CONSTRAINT tilepage_tileset_id_fkey FOREIGN KEY (tileset_id) REFERENCES $POSTGRES_SCHEMA.tileset (key) MATCH SIMPLE ON UPDATE NO ACTION ON DELETE CASCADE)"
  fi

}

gwc_file_perms() {
  create_dir "${GEOWEBCACHE_CACHE_DIR}"

  # Ensure directory exists before trying to stat it
  if [[ ! -d "${GEOWEBCACHE_CACHE_DIR}" ]]; then
    echo -e "\e[31m [Entrypoint] ERROR: Failed to create ${GEOWEBCACHE_CACHE_DIR} \033[0m"
    return 1
  fi

  GEO_USER_PERM=$(stat -c '%U' "${GEOSERVER_DATA_DIR}")
  GEO_GRP_PERM=$(stat -c '%G' "${GEOSERVER_DATA_DIR}")
  GWC_USER_PERM=$(stat -c '%U' "${GEOWEBCACHE_CACHE_DIR}")
  GWC_GRP_PERM=$(stat -c '%G' "${GEOWEBCACHE_CACHE_DIR}")
  case "${GEOWEBCACHE_CACHE_DIR}" in ${GEOSERVER_DATA_DIR}/*)
    echo -e " \e[32m [Entrypoint] \033[0m \e[1;31m ${GEOWEBCACHE_CACHE_DIR} \033[0m \e[32m is nested in \033[0m \e[1;31m ${GEOSERVER_DATA_DIR} \033[0m"
    if [[ ${CHOWN_DATA_DIR} =~ [Tt][Rr][Uu][Ee] ]];then
      if [[ ${GEO_USER_PERM} != "${USER_NAME}" ]] ||  [[ ${GEO_GRP_PERM} != "${GEO_GROUP_NAME}"  ]];then
        echo -e "\e[32m [Entrypoint] Changing folder permission for:\033[0m \e[1;31m ${GEOSERVER_DATA_DIR} \033[0m"
        chown -R "${USER_NAME}":"${GEO_GROUP_NAME}" "${GEOSERVER_DATA_DIR}"
      fi
    fi
    ;;
  *)
    echo -e "\e[1;31m ${GEOWEBCACHE_CACHE_DIR} \033[0m is not nested in \e[1;31m ${GEOSERVER_DATA_DIR} \033[0m"
    if [[ ${CHOWN_DATA_DIR} =~ [Tt][Rr][Uu][Ee] ]];then
      if [[ ${GEO_USER_PERM} != "${USER_NAME}" ]] ||  [[ ${GEO_GRP_PERM} != "${GEO_GROUP_NAME}"  ]];then
        echo -e "\e[32m [Entrypoint] Changing folder permission for:\033[0m \e[1;31m ${GEOSERVER_DATA_DIR} \033[0m"
        chown -R "${USER_NAME}":"${GEO_GROUP_NAME}" "${GEOSERVER_DATA_DIR}"
      fi
    fi
    if [[ ${CHOWN_GWC_DATA_DIR} =~ [Tt][Rr][Uu][Ee] ]];then
      if [[ ${GWC_USER_PERM} != "${USER_NAME}" ]] ||  [[ ${GWC_GRP_PERM} != "${GEO_GROUP_NAME}"  ]];then
        echo -e "\e[32m [Entrypoint] Changing folder permission for:\033[0m \e[1;31m ${GEOWEBCACHE_CACHE_DIR} \033[0m"
        chown -R "${USER_NAME}":"${GEO_GROUP_NAME}" "${GEOWEBCACHE_CACHE_DIR}"
      fi
    fi
   ;;
esac

}

entry_point_script() {
  if find "/docker-entrypoint-geoserver.d" -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
    for f in /docker-entrypoint-geoserver.d/*; do
      case "$f" in
        *.sh) echo "$0: running $f"; . "$f" || true ;;
        *)    echo "$0: ignoring $f" ;;
      esac
      echo
    done
  fi
}



setup_monitoring() {
  create_dir "${MONITOR_AUDIT_PATH}"
  export MONITORING_AUDIT_ENABLED MONITORING_AUDIT_ROLL_LIMIT MONITORING_STORAGE MONITORING_MODE MONITORING_SYNC MONITORING_BODY_SIZE MONITORING_BBOX_LOG_CRS MONITORING_BBOX_LOG_LEVEL
  if [[ -f "${EXTRA_CONFIG_DIR}"/monitor.properties ]]; then
        envsubst < "${EXTRA_CONFIG_DIR}"/monitor.properties > "${GEOSERVER_DATA_DIR}"/monitoring/monitor.properties
  else

  cat > "${GEOSERVER_DATA_DIR}"/monitoring/monitor.properties <<EOF
audit.enabled=${MONITORING_AUDIT_ENABLED}
audit.roll_limit=${MONITORING_AUDIT_ROLL_LIMIT}
storage=${MONITORING_STORAGE}
mode=${MONITORING_MODE}
sync=${MONITORING_SYNC}
maxBodySize=${MONITORING_BODY_SIZE}
bboxLogCrs=${MONITORING_BBOX_LOG_CRS}
bboxLogLevel=${MONITORING_BBOX_LOG_LEVEL}
EOF
  fi

}

setup_monitoring_status() {
  create_dir "${MONITOR_AUDIT_PATH}"
  export MONITORING_AUDIT_ENABLED MONITORING_AUDIT_ROLL_LIMIT MONITORING_STORAGE MONITORING_MODE MONITORING_SYNC MONITORING_BODY_SIZE MONITORING_BBOX_LOG_CRS MONITORING_BBOX_LOG_LEVEL
  setup_monitoring
}

setup_jdbc_db_config() {
    if [[ ${ext} == 'jdbcconfig-plugin' ]];then
        if [[  ${DB_BACKEND} =~ [Pp][Oo][Ss][Tt][Gg][Rr][Ee][Ss] ]]; then
            PGPASSWORD="${POSTGRES_PASS}"
            export PGPASSWORD
            postgres_ready_status "${HOST}" "${POSTGRES_PORT}" "${POSTGRES_USER}" "$POSTGRES_DB"
            create_dir "${GEOSERVER_DATA_DIR}"/jdbcconfig
            cp -rn /build_data/jdbcconfig/scripts "${GEOSERVER_DATA_DIR}"/jdbcconfig/
            postgres_ssl_setup
            export SSL_PARAMETERS=${PARAMS}
            if [[ -f "${EXTRA_CONFIG_DIR}"/jdbcconfig.properties ]]; then
              envsubst < "${EXTRA_CONFIG_DIR}"/jdbcconfig.properties > "${GEOSERVER_DATA_DIR}"/jdbcconfig/jdbcconfig.properties
            else
              envsubst < /build_data/jdbcconfig/jdbcconfig.properties > "${GEOSERVER_DATA_DIR}"/jdbcconfig/jdbcconfig.properties
              sed -i '/^jndiName=/d' "${GEOSERVER_DATA_DIR}"/jdbcconfig/jdbcconfig.properties
              if [[ ${POSTGRES_JNDI} =~ [Tt][Rr][Uu][Ee] ]];then
                # Set jndiName if POSTGRES_JNDI is set to true
                echo "jndiName=java:comp/env/jdbc/postgres" >> "${GEOSERVER_DATA_DIR}"/jdbcconfig/jdbcconfig.properties
              fi
            fi

            check_jdbc_config_table=$(psql -d "$POSTGRES_DB" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -h "$HOST" -tAc "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'object_property')")
            if [[  ${check_jdbc_config_table} = "t" ]]; then
              sed -i 's/initdb=true/initdb=false/g' "${GEOSERVER_DATA_DIR}"/jdbcconfig/jdbcconfig.properties
              sed -i 's/import=true/import=false/g' "${GEOSERVER_DATA_DIR}"/jdbcconfig/jdbcconfig.properties
            fi
        else
            echo "skipping jdbc config and will use default settings"
        fi
    fi
}


setup_jdbc_db_store() {
    if [[ ${ext} == 'jdbcstore-plugin' ]];then
        PGPASSWORD="${POSTGRES_PASS}"
        export PGPASSWORD
        postgres_ready_status "${HOST}" "${POSTGRES_PORT}" "${POSTGRES_USER}" "$POSTGRES_DB"
        if [[  ${DB_BACKEND} =~ [Pp][Oo][Ss][Tt][Gg][Rr][Ee][Ss] ]]; then
            create_dir "${GEOSERVER_DATA_DIR}"/jdbcstore
            create_dir "${GEOSERVER_DATA_DIR}"/jdbcconfig
            cp -rn /build_data/jdbcstore/scripts "${GEOSERVER_DATA_DIR}"/jdbcstore/
            cp -rn /build_data/jdbcconfig/scripts "${GEOSERVER_DATA_DIR}"/jdbcconfig/
            postgres_ssl_setup
            export SSL_PARAMETERS=${PARAMS}
            if [[ -f "${EXTRA_CONFIG_DIR}"/jdbcconfig.properties ]]; then
              envsubst < "${EXTRA_CONFIG_DIR}"/jdbcconfig.properties > "${GEOSERVER_DATA_DIR}"/jdbcconfig/jdbcconfig.properties
            else
              envsubst < /build_data/jdbcconfig/jdbcconfig.properties > "${GEOSERVER_DATA_DIR}"/jdbcconfig/jdbcconfig.properties
            fi
            if [[ -f "${EXTRA_CONFIG_DIR}"/jdbcstore.properties ]]; then
              envsubst < "${EXTRA_CONFIG_DIR}"/jdbcstore.properties > "${GEOSERVER_DATA_DIR}"/jdbcstore/jdbcstore.properties
            else
              envsubst < /build_data/jdbcstore/jdbcstore.properties > "${GEOSERVER_DATA_DIR}"/jdbcstore/jdbcstore.properties
              sed -i '/^jndiName=/d' "${GEOSERVER_DATA_DIR}"/jdbcstore/jdbcstore.properties
              if [[ ${POSTGRES_JNDI} =~ [Tt][Rr][Uu][Ee] ]];then
                # Set jndiName if POSTGRES_JNDI is set to true
                echo "jndiName=java:comp/env/jdbc/postgres" >> "${GEOSERVER_DATA_DIR}"/jdbcstore/jdbcstore.properties
              fi
            fi

            check_jdbc_store_table=$(psql -d "$POSTGRES_DB" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" -h "${HOST}" -tAc "SELECT EXISTS(SELECT 1 from information_schema.tables where table_name = 'resources')")
            if [[  ${check_jdbc_store_table} = "t" ]]; then
              sed -i 's/initdb=true/initdb=false/g' "${GEOSERVER_DATA_DIR}"/jdbcstore/jdbcstore.properties
              sed -i 's/import=true/import=false/g' "${GEOSERVER_DATA_DIR}"/jdbcstore/jdbcstore.properties
            fi
            check_jdbc_config_table=$(psql -d "$POSTGRES_DB" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -h "$HOST" -tAc "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'object_property')")
            if [[  ${check_jdbc_config_table} = "t" ]]; then
              sed -i 's/initdb=true/initdb=false/g' "${GEOSERVER_DATA_DIR}"/jdbcconfig/jdbcconfig.properties
              sed -i 's/import=true/import=false/g' "${GEOSERVER_DATA_DIR}"/jdbcconfig/jdbcconfig.properties
            fi
        else
          echo "skipping jdbc store config and will use default settings"
        fi
    fi
}

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

install_fonts() {
  ls "${FONTS_DIR}"/*.ttf >/dev/null 2>&1 && cp -rf "${FONTS_DIR}"/*.ttf /usr/share/fonts/truetype/
  ls "${FONTS_DIR}"/*.otf >/dev/null 2>&1 && cp -rf "${FONTS_DIR}"/*.otf /usr/share/fonts/opentype/
  setup_google_fonts
}

install_sample_data(){
  if [[ ${SAMPLE_DATA} =~ [Tt][Rr][Uu][Ee] ]]; then
    cp -r "${CATALINA_HOME}"/data/* "${GEOSERVER_DATA_DIR}"
  fi
}

setup_google_fonts() {
  [[ -z "${GOOGLE_FONTS_NAMES}" ]] && return

  git clone --filter=blob:none --no-checkout https://github.com/google/fonts.git
  cd fonts || return
  git config core.sparsecheckout true

  for gfont in ${GOOGLE_FONTS_NAMES//,/ }; do
    grep -Fxq "$gfont" /build_data/google_fonts.txt &&
      echo "ofl/$gfont" >> .git/info/sparse-checkout
  done

  git checkout main

  for gfont in ${GOOGLE_FONTS_NAMES//,/ }; do
    grep -Fxq "$gfont" /build_data/google_fonts.txt &&
      cp -r "ofl/$gfont" /usr/share/fonts/truetype/
  done

  cd ..
  rm -rf fonts
}

cleanup_data_dir() {
  [[ "${RECREATE_DATADIR}" =~ [Tt][Rr][Uu][Ee] ]] &&
    rm -rf "${GEOSERVER_DATA_DIR:?}/"*
}

setup_s3_extension() {
  export S3_SERVER_URL S3_USERNAME S3_PASSWORD S3_ALIAS

  if [[ -z "${S3_SERVER_URL}" || -z "${S3_USERNAME}" || -z "${S3_PASSWORD}" || -z "${S3_ALIAS}" ]]; then
    echo -e "\e[32m [Entrypoint] Missing S3 vars, skipping s3.properties \033[0m"
    return
  fi

  if [[ "${ADDITIONAL_JAVA_STARTUP_OPTIONS}" == *"-Ds3.properties.location"* ]]; then
    s3_config
  else
    echo -e "\e[32m [Entrypoint] -Ds3.properties.location not set, skipping S3 \033[0m"
  fi
}


setup_stable_extensions(){

  generate_stable_extensions_config
  download_extensions_config "${STABLE_PLUGINS_DIR}/curl.cfg"

  local extensions

  if [[ "$ACTIVE_EXTENSIONS" != "$DEFAULT_EXTENSIONS" ]]; then
      extensions="${ACTIVE_EXTENSIONS}"
  else
      extensions="${DEFAULT_EXTENSIONS}"
  fi

  for ext in $(echo "${extensions}" | tr ',' ' '); do

      if echo "${DEFAULT_EXTENSIONS}" | grep -w "${ext}" >/dev/null; then
          install_plugin "${REQUIRED_PLUGINS_DIR}" "${ext}"
      else
          install_plugin "${STABLE_PLUGINS_DIR}" "${ext}"
      fi

  done
}

setup_community_extensions(){

  if [[ ! -z ${COMMUNITY_EXTENSIONS} ]]; then
    if  [[ ${FORCE_DOWNLOAD_COMMUNITY_EXTENSIONS} =~ [Tt][Rr][Uu][Ee] ]];then
      rm -rf ${COMMUNITY_PLUGINS_DIR}/*.zip
    fi

  generate_community_extensions_config
  download_extensions_config "${COMMUNITY_PLUGINS_DIR}/curl.cfg"

  for ext in $(echo "${COMMUNITY_EXTENSIONS}" | tr ',' ' '); do
      if [[ -f ${COMMUNITY_PLUGINS_DIR}/${ext}.zip ]]; then

        setup_jdbc_db_store
        setup_jdbc_db_config
        setup_hz_cluster
        install_plugin ${COMMUNITY_PLUGINS_DIR} "${ext}"
      fi
  done

fi

}

setup_community_extensions_status() {
  export JDBC_CONFIG_ENABLED JDBC_IGNORE_PATHS JDBC_STORE_ENABLED POSTGRES_JNDI
  setup_community_extensions
}

setup_extensions(){


  DEFAULT_EXTENSIONS=''
  for plugin in $(cat ${REQUIRED_PLUGINS_DIR}/required_plugins.txt); do
    if [ -z "$DEFAULT_EXTENSIONS" ]; then
      DEFAULT_EXTENSIONS=${plugin}
    else
      DEFAULT_EXTENSIONS=${DEFAULT_EXTENSIONS},${plugin}
    fi
  done

  if [[ -z ${ACTIVE_EXTENSIONS} ]];then
    ACTIVE_EXTENSIONS=${DEFAULT_EXTENSIONS},${STABLE_EXTENSIONS}
  fi

  # If FORCE_DOWNLOAD_STABLE_EXTENSIONS is true, remove all stable extensions
  if [[ ${FORCE_DOWNLOAD_STABLE_EXTENSIONS} =~ [Tt][Rr][Uu][Ee] ]]; then
    rm -rf ${STABLE_PLUGINS_DIR}/*.zip
    rm -rf ${REQUIRED_PLUGINS_DIR}/*.zip
  fi

  setup_stable_extensions
}

generate_community_extensions_config() {
  local cfg_file="${COMMUNITY_PLUGINS_DIR}/curl.cfg"
  rm -f "$cfg_file"

  for ext in $(echo "${COMMUNITY_EXTENSIONS}" | tr ',' ' '); do
    local output_file="${COMMUNITY_PLUGINS_DIR}/${ext}.zip"

    if [[ -f "$output_file" ]]; then
      echo -e "[Entrypoint] Community Extension already exists, skipping download of : \e[1;31m $ext \033[0m"
      continue
    fi

    echo "url = \"https://build.geoserver.org/geoserver/${GS_VERSION:0:5}x/community-latest/geoserver-${GS_VERSION:0:4}-SNAPSHOT-${ext}.zip\"" >> "$cfg_file"
    echo "output = \"${output_file}\"" >> "$cfg_file"
    echo "--fail" >> "$cfg_file"
    echo "--location" >> "$cfg_file"
    echo "" >> "$cfg_file"
  done
}

generate_stable_extensions_config() {
  local cfg_file="${STABLE_PLUGINS_DIR}/curl.cfg"
  rm -f "$cfg_file"

  local extensions

  if [[ "$ACTIVE_EXTENSIONS" != "$DEFAULT_EXTENSIONS" ]]; then
      extensions="${ACTIVE_EXTENSIONS}"
  else
      extensions="${DEFAULT_EXTENSIONS}"
  fi

  for ext in $(echo "${extensions}" | tr ',' ' '); do

    if echo "${DEFAULT_EXTENSIONS}" | grep -w "${ext}" >/dev/null; then
        output_file="${REQUIRED_PLUGINS_DIR}/${ext}.zip"
    else
        output_file="${STABLE_PLUGINS_DIR}/${ext}.zip"
    fi

    # Skip if already downloaded
    if [[ -f "$output_file" ]]; then
        echo -e "[Entrypoint] Extension already exists : \e[1;31m $ext \033[0m"
        continue
    fi

    plugin_url="${STABLE_PLUGIN_BASE_URL}/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-${ext}.zip"

    echo "url = \"${plugin_url}\"" >> "$cfg_file"
    echo "output = \"${output_file}\"" >> "$cfg_file"
    echo "--fail" >> "$cfg_file"
    echo "--location" >> "$cfg_file"
    echo "" >> "$cfg_file"

  done
}



download_extensions_config() {
  local cfg_file="${1:-/work/curl.cfg}"

  # Only proceed if config exists and has content
  if [[ ! -s "$cfg_file" ]]; then
    echo "No extensions to download"
    return 0
  fi

  for attempt in {1..5}; do
    echo "Attempt $attempt of downloading plugins"

    if curl --progress-bar -K "$cfg_file"; then
      echo "Download successful"
      return 0
    else
      echo "Download failed, retrying in 5 seconds..."
      sleep 5
    fi
  done

  echo "Download failed after multiple attempts"
  return 1
}

sync_gdal_version() {
  local install_dir lib_dir version

  install_dir="$(detect_install_dir)"
  lib_dir="${install_dir}/webapps/${GEOSERVER_CONTEXT_ROOT}/WEB-INF/lib"

  cp "${REQUIRED_PLUGINS_DIR}/log4j-layout-template-json.jar" "${lib_dir}/"

  for jar in "${lib_dir}"/gdal-*.jar; do
    version="$(basename "$jar" | sed 's/gdal-\(.*\)\.jar/\1/')"
    break
  done

  GDAL_VERSION="$(gdalinfo --version | awk '{print $2}' | tr -d ,)"

  [[ "${GDAL_VERSION}" == "${version}" ]] || {
    rm -f "${lib_dir}/gdal-${version}.jar"
    cp "/usr/share/java/gdal-${GDAL_VERSION}.jar" "${lib_dir}/"
  }
}

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
  if [[ -f /build_data/jdom2-2.0.6.1.jar ]];then
    cp /build_data/jdom2-2.0.6.1.jar \
      "${CATALINA_HOME}/webapps/${GEOSERVER_CONTEXT_ROOT}/WEB-INF/lib/"
  fi
}

setup_jndi_status() {
  if [[ ${POSTGRES_JNDI} =~ [Tt][Rr][Uu][Ee] ]]; then
    postgres_ssl_setup
    export SSL_PARAMETERS=${PARAMS}

    : "${POSTGRES_PORT:=5432}"
    export POSTGRES_PORT

    # Remove PostgreSQL jars from GeoServer WEB-INF
    POSTGRES_JAR_COUNT=$(ls -1 ${CATALINA_HOME}/webapps/${GEOSERVER_CONTEXT_ROOT}/WEB-INF/lib/postgresql-* 2>/dev/null | wc -l)
    if [ "$POSTGRES_JAR_COUNT" != 0 ]; then
      rm "${CATALINA_HOME}"/webapps/"${GEOSERVER_CONTEXT_ROOT}"/WEB-INF/lib/postgresql-*
    fi

    # Install JDBC driver into Tomcat
    cp "${CATALINA_HOME}/postgres_config/postgresql-"* \
       "${CATALINA_HOME}/lib/"

    if [[ -f "${EXTRA_CONFIG_DIR}/context.xml" ]]; then
      envsubst < "${EXTRA_CONFIG_DIR}/context.xml" \
        > "${CATALINA_HOME}/conf/context.xml"
    else
      envsubst < /build_data/context.xml \
        > "${CATALINA_HOME}/conf/context.xml"
    fi
  else
    # Fallback: bundle JDBC with GeoServer
    cp "${CATALINA_HOME}/postgres_config/postgresql-"* \
       "${CATALINA_HOME}/webapps/${GEOSERVER_CONTEXT_ROOT}/WEB-INF/lib/"
  fi
}

setup_tomcat_webapp_status() {
  if [[ "${TOMCAT_EXTRAS}" =~ [Tt][Rr][Uu][Ee] ]]; then
    unzip -qq "${REQUIRED_PLUGINS_DIR}/tomcat_apps.zip" -d /tmp/

    cp -r /tmp/tomcat_apps/* "${CATALINA_HOME}/webapps/"
    rm -rf /tmp/tomcat_apps

    # Manager context.xml when JNDI disabled
    if [[ ${POSTGRES_JNDI} =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
      if [[ -f "${EXTRA_CONFIG_DIR}/context.xml" ]]; then
        envsubst < "${EXTRA_CONFIG_DIR}/context.xml" \
          > "${CATALINA_HOME}/webapps/manager/META-INF/context.xml"
      else
        cp /build_data/context.xml \
           "${CATALINA_HOME}/webapps/manager/META-INF/"
        sed -i '19,36d' \
          "${CATALINA_HOME}/webapps/manager/META-INF/context.xml"
      fi
    fi

    # Setup Tomcat credentials
    export TOMCAT_USER
    if [[ -z ${TOMCAT_PASSWORD} ]]; then
      generate_random_string 18
      TOMCAT_PASSWORD=${RAND}
      echo "${TOMCAT_PASSWORD}" > "${GEOSERVER_DATA_DIR}/tomcat_pass.txt"
      delete_file "${CATALINA_HOME}/conf/tomcat-users.xml"
      tomcat_user_config
      unset TOMCAT_PASSWORD RAND
    else
      tomcat_user_config
    fi
  else
    # Harden Tomcat: remove default apps
    delete_folder "${CATALINA_HOME}/webapps/ROOT"
    delete_folder "${CATALINA_HOME}/webapps/docs"
    delete_folder "${CATALINA_HOME}/webapps/examples"
    delete_folder "${CATALINA_HOME}/webapps/host-manager"
    delete_folder "${CATALINA_HOME}/webapps/manager"

    if [[ "${ROOT_WEBAPP_REDIRECT}" =~ [Tt][Rr][Uu][Ee] ]]; then
      mkdir -p "${CATALINA_HOME}/webapps/ROOT"
      sed "s@/geoserver/@/${GEOSERVER_CONTEXT_ROOT}/@g" \
        /build_data/index.jsp \
        > "${CATALINA_HOME}/webapps/ROOT/index.jsp"
    fi
  fi
}

setup_tomcat_ssl_status() {

  ############################################
  # Temp cleanup helpers
  ############################################
  TMP_FILES=()

  cleanup_temp() {
    for f in "${TMP_FILES[@]}"; do
      [ -f "$f" ] && rm -f "$f"
    done
  }

  trap cleanup_temp EXIT

  ############################################
  # SSL handling
  ############################################
  if [[ "${SSL}" =~ ^([Tt][Rr][Uu][Ee]|1)$ ]]; then

    # Defaults
    JKS_FILE="${JKS_FILE:-letsencrypt.jks}"
    KEY_ALIAS="${KEY_ALIAS:-letsencrypt}"
    P12_FILE="${P12_FILE:-letsencrypt.p12}"

    file_env JKS_KEY_PASSWORD
    if [ -z "${JKS_KEY_PASSWORD}" ]; then
      generate_random_string 22
      JKS_KEY_PASSWORD="$RAND"
      echo "JKS_KEY_PASSWORD" >> /tmp/set_vars.txt
      unset RAND
    fi

    file_env JKS_STORE_PASSWORD
    if [ -z "${JKS_STORE_PASSWORD}" ]; then
      generate_random_string 23
      JKS_STORE_PASSWORD="$RAND"
      echo "JKS_STORE_PASSWORD" >> /tmp/set_vars.txt
      unset RAND
    fi

    file_env PKCS12_PASSWORD
    if [ -z "${PKCS12_PASSWORD}" ]; then
      generate_random_string 24
      PKCS12_PASSWORD="$RAND"
      echo "PKCS12_PASSWORD" >> /tmp/set_vars.txt
      unset RAND
    fi

    export PKCS12_PASSWORD JKS_KEY_PASSWORD JKS_STORE_PASSWORD

    ############################################
    # Prepare cert directory
    ############################################
    mkdir -p "${CERT_DIR}"

    rm -f \
      "${CERT_DIR}/${P12_FILE}" \
      "${CERT_DIR}/${JKS_FILE}" \
      "${CERT_DIR}/privkey.pem" \
      "${CERT_DIR}/fullchain.pem"

    ############################################
    # Optional mounted certificate
    ############################################
    if [ -f "${EXTRA_CONFIG_DIR}/certificate.pfx" ]; then
      cp "${EXTRA_CONFIG_DIR}/certificate.pfx" "${CERT_DIR}/certificate.pfx"
      TMP_FILES+=("${CERT_DIR}/certificate.pfx")
    fi

    ############################################
    # Extract or generate certs
    ############################################
    if [[ -f "${CERT_DIR}/certificate.pfx" ]]; then
      openssl pkcs12 -in "${CERT_DIR}/certificate.pfx" \
        -nocerts -nodes \
        -out "${CERT_DIR}/privkey.pem" \
        -passin pass:"${PKCS12_PASSWORD}"

      openssl pkcs12 -in "${CERT_DIR}/certificate.pfx" \
        -clcerts -nokeys \
        -out "${CERT_DIR}/fullchain.pem" \
        -passin pass:"${PKCS12_PASSWORD}"
    fi

    if [[ ! -f "${CERT_DIR}/fullchain.pem" ]]; then
      openssl req -x509 -newkey rsa:4096 \
        -keyout "${CERT_DIR}/privkey.pem" \
        -out "${CERT_DIR}/fullchain.pem" \
        -days 3650 -nodes -sha256 \
        -subj '/CN=geoserver'
    fi

    ############################################
    # PEM → PKCS12 → JKS
    ############################################
    openssl pkcs12 -export \
      -in "${CERT_DIR}/fullchain.pem" \
      -inkey "${CERT_DIR}/privkey.pem" \
      -name "${KEY_ALIAS}" \
      -out "${CERT_DIR}/${P12_FILE}" \
      -password pass:"${PKCS12_PASSWORD}"

    keytool -importkeystore \
      -noprompt \
      -trustcacerts \
      -alias "${KEY_ALIAS}" \
      -destkeystore "${CERT_DIR}/${JKS_FILE}" \
      -deststorepass "${JKS_STORE_PASSWORD}" \
      -destkeypass "${JKS_KEY_PASSWORD}" \
      -srckeystore "${CERT_DIR}/${P12_FILE}" \
      -srcstoretype PKCS12 \
      -srcstorepass "${PKCS12_PASSWORD}"

    SSL_CONF="${CATALINA_HOME}/conf/ssl-tomcat.xsl"

  ############################################
  # SSL disabled
  ############################################
  else
    SSL_CONF="${CATALINA_HOME}/conf/ssl-tomcat_no_https.xsl"
    cp "${CATALINA_HOME}/conf/ssl-tomcat.xsl" "${SSL_CONF}"
    sed -i '95,138d' "${SSL_CONF}"
    TMP_FILES+=("${SSL_CONF}")
  fi

  ############################################
  # XSLT parameter building (unchanged)
  ############################################
  [ -n "$HTTP_PORT" ] && HTTP_PORT_PARAM="--stringparam http.port $HTTP_PORT "
  [ -n "$HTTP_PROXY_NAME" ] && HTTP_PROXY_NAME_PARAM="--stringparam http.proxyName $HTTP_PROXY_NAME "
  [ -n "$HTTP_PROXY_PORT" ] && HTTP_PROXY_PORT_PARAM="--stringparam http.proxyPort $HTTP_PROXY_PORT "
  [ -n "$HTTP_REDIRECT_PORT" ] && HTTP_REDIRECT_PORT_PARAM="--stringparam http.redirectPort $HTTP_REDIRECT_PORT "
  [ -n "$HTTP_CONNECTION_TIMEOUT" ] && HTTP_CONNECTION_TIMEOUT_PARAM="--stringparam http.connectionTimeout $HTTP_CONNECTION_TIMEOUT "
  [ -n "$HTTP_COMPRESSION" ] && HTTP_COMPRESSION_PARAM="--stringparam http.compression $HTTP_COMPRESSION "
  [ -n "$HTTP_SCHEME" ] && HTTP_SCHEME_PARAM="--stringparam http.scheme $HTTP_SCHEME "
  [ -n "$HTTP_MAX_HEADER_SIZE" ] && HTTP_MAX_HEADER_SIZE_PARAM="--stringparam http.maxHttpHeaderSize $HTTP_MAX_HEADER_SIZE "

  [[ "$HTTP_RELAX_CHARS" =~ ^([Tt][Rr][Uu][Ee]|1)$ ]] && \
    HTTP_RELAX_CHARS_PARAM="--stringparam http.relaxedPathChars {}[]\| "

  [[ "$HTTP_RELAX_QUERY" =~ ^([Tt][Rr][Uu][Ee]|1)$ ]] && \
    HTTP_RELAX_QUERY_PARAM="--stringparam http.relaxedQueryChars {}[]\| "

  [ -n "$HTTPS_PORT" ] && HTTPS_PORT_PARAM="--stringparam https.port $HTTPS_PORT "
  [ -n "$JKS_FILE" ] && JKS_FILE_PARAM="--stringparam https.keystoreFile ${CERT_DIR}/${JKS_FILE} "
  [ -n "$JKS_KEY_PASSWORD" ] && JKS_KEY_PASSWORD_PARAM="--stringparam https.keystorePass $JKS_KEY_PASSWORD "
  [ -n "$KEY_ALIAS" ] && KEY_ALIAS_PARAM="--stringparam https.keyAlias $KEY_ALIAS "
  [ -n "$JKS_STORE_PASSWORD" ] && JKS_STORE_PASSWORD_PARAM="--stringparam https.keyPass $JKS_STORE_PASSWORD "

  ############################################
  # Apply transform
  ############################################
  if [[ -f "${EXTRA_CONFIG_DIR}/server.xml" ]]; then
    cp -f "${EXTRA_CONFIG_DIR}/server.xml" "${CATALINA_HOME}/conf/"
  else
    xsltproc \
      --output "${CATALINA_HOME}/conf/server.xml" \
      $HTTP_PORT_PARAM \
      $HTTP_PROXY_NAME_PARAM \
      $HTTP_PROXY_PORT_PARAM \
      $HTTP_REDIRECT_PORT_PARAM \
      $HTTP_CONNECTION_TIMEOUT_PARAM \
      $HTTP_COMPRESSION_PARAM \
      $HTTP_SCHEME_PARAM \
      $HTTP_RELAX_CHARS_PARAM \
      $HTTP_RELAX_QUERY_PARAM \
      $HTTP_MAX_HEADER_SIZE_PARAM \
      $HTTPS_PORT_PARAM \
      $JKS_FILE_PARAM \
      $JKS_KEY_PASSWORD_PARAM \
      $KEY_ALIAS_PARAM \
      $JKS_STORE_PASSWORD_PARAM \
      "${SSL_CONF}" \
      "${CATALINA_HOME}/conf/server.xml"

    if [[ "${ACTIVATE_PROXY_HEADERS}" =~ ^([Tt][Rr][Uu][Ee]|1)$ ]]; then
      sed -i -r '/\<\Host\>/ i\ \t<Valve className="org.apache.catalina.valves.RemoteIpValve" remoteIpHeader="x-forwarded-for" protocolHeader="x-forwarded-proto" />' \
        "${CATALINA_HOME}/conf/server.xml"
    fi
  fi

  ############################################
  # Hardening
  ############################################
  sed -i 's/8005/-1/g' "${CATALINA_HOME}/conf/server.xml"
}

clean_up_vars() {
  if [[ -f /tmp/set_vars.txt ]]; then
    for vars in $(cat /tmp/set_vars.txt); do unset "$vars"; done
    rm /tmp/set_vars.txt
  fi
}

# TODO: update hookpath
run_update_password_hook() {
  #local hook="${SCRIPT_DIR}/lib/update_passwords.sh"
  local hook="/scripts/update_passwords.sh"

  [[ -n "${EXISTING_DATA_DIR}" ]] && return

  if [[ -x "${hook}" ]]; then
    /bin/bash "${hook}"
  elif [[ -f "${hook}" ]]; then
    /bin/bash "${hook}"
  fi
}


setup_community_extensions_status() {
  export JDBC_CONFIG_ENABLED JDBC_STORE_ENABLED POSTGRES_JNDI
  setup_community_extensions
}