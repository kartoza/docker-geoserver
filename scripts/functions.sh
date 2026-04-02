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

# Function to setup control flow https://docs.geoserver.org/stable/en/user/extensions/controlflow/index.html
setup_control_flow() {
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



tomcat_logging() {
  if [[ -f "${EXTRA_CONFIG_DIR}/logging.properties" ]]; then
    envsubst < "${EXTRA_CONFIG_DIR}/logging.properties" > "${CATALINA_HOME}/conf/logging.properties"
  else
    envsubst < /build_data/logging.properties > "${CATALINA_HOME}/conf/logging.properties"
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

