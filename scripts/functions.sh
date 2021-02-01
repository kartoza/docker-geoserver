#!/usr/bin/env bash


export request="wget --progress=bar:force:noscroll -c --no-check-certificate"

function create_dir() {
  DATA_PATH=$1

  if [[ ! -d ${DATA_PATH} ]]; then
    echo "Creating" ${DATA_PATH} "directory"
    mkdir -p ${DATA_PATH}
  fi
}

# Helper function to download extensions
function download_extension() {
  URL=$1
  PLUGIN=$2
  if curl --output /dev/null --silent --head --fail "${URL}"; then
    echo "URL exists: ${URL}"
    ${request} "${URL}" -O ${PLUGIN}.zip
  else
    echo "URL does not exist: ${URL}"
  fi

}

# A little logic that will fetch the geoserver war zip file if it is not available locally in the resources dir
function download_geoserver() {

  if [[ ! -f /tmp/resources/geoserver-${GS_VERSION}.zip ]]; then
  if [[ "${WAR_URL}" == *\.zip ]]; then
    destination=/tmp/resources/geoserver-${GS_VERSION}.zip
    ${request} ${WAR_URL} -O ${destination}
    unzip /tmp/resources/geoserver-${GS_VERSION}.zip -d /tmp/geoserver
  else
    destination=/tmp/geoserver/geoserver.war
    mkdir -p /tmp/geoserver/ &&
    ${request} ${WAR_URL} -O ${destination}
  fi
else
  unzip /tmp/resources/geoserver-${GS_VERSION}.zip -d /tmp/geoserver
fi


}

# Helper function to setup cluster config for the clustering plugin
function cluster_config() {
  if [[ -f ${CLUSTER_CONFIG_DIR}/cluster.properties ]]; then
    rm "${CLUSTER_CONFIG_DIR}"/cluster.properties
  fi

if [[ ${CLUSTERING} =~ [Tt][Rr][Uu][Ee] ]]; then
  cat >>${CLUSTER_CONFIG_DIR}/cluster.properties <<EOF
CLUSTER_CONFIG_DIR=${CLUSTER_CONFIG_DIR}
instanceName=${INSTANCE_STRING}
readOnly=${READONLY}
durable=${CLUSTER_DURABILITY}
brokerURL=${BROKER_URL}
embeddedBroker=${EMBEDDED_BROKER}
connection.retry=10
toggleMaster=${TOGGLE_MASTER}
xbeanURL=./broker.xml
embeddedBrokerProperties=embedded-broker.properties
topicName=VirtualTopic.geoserver
connection=enabled
toggleSlave=${TOGGLE_SLAVE}
connection.maxwait=500
group=geoserver-cluster
EOF
fi
}

# Helper function to setup broker config. Used with clustering configs

function broker_config() {
  if [[ -f ${CLUSTER_CONFIG_DIR}/embedded-broker.properties ]]; then
    rm "${CLUSTER_CONFIG_DIR}"/embedded-broker.properties
  fi

if [[ ${CLUSTERING} =~ [Tt][Rr][Uu][Ee] ]]; then
  cat >>${CLUSTER_CONFIG_DIR}/embedded-broker.properties <<EOF
activemq.jmx.useJmx=false
activemq.jmx.port=1098
activemq.jmx.host=localhost
activemq.jmx.createConnector=false
activemq.transportConnectors.server.uri=${BROKER_URL}?maximumConnections=1000&wireFormat.maxFrameSize=104857600&jms.useAsyncSend=true&transport.daemon=true&trace=true
activemq.transportConnectors.server.discoveryURI=multicast://default
activemq.broker.persistent=true
activemq.broker.systemUsage.memoryUsage=128 mb
activemq.broker.systemUsage.storeUsage=1 gb
activemq.broker.systemUsage.tempUsage=128 mb
EOF
fi
}

# Helper function to configure s3 bucket
function s3_config() {
  if [[ -f "${GEOSERVER_DATA_DIR}"/s3.properties ]]; then
    rm "${GEOSERVER_DATA_DIR}"/s3.properties
  fi

  cat >"${GEOSERVER_DATA_DIR}"/s3.properties <<EOF
alias.s3.endpoint=${S3_SERVER_URL}
alias.s3.user=${S3_USERNAME}
alias.s3.password=${S3_PASSWORD}
EOF

}

# Helper function to install plugin in proper path

function install_plugin() {
  DATA_PATH=/community_plugins
  if [ -n "$1" ]; then
    DATA_PATH=$1
  fi
  EXT=$2

  unzip ${DATA_PATH}/${EXT}.zip -d /tmp/gs_plugin &&
    cp -r -u -p /tmp/gs_plugin/*.jar "${CATALINA_HOME}"/webapps/geoserver/WEB-INF/lib/ &&
    rm -rf /tmp/gs_plugin

}

# Helper function to setup disk quota configs and database configurations

function disk_quota_config() {
  if [[  ${DB_BACKEND} == 'POSTGRES' ]]; then

if [[ ! -f ${GEOWEBCACHE_CACHE_DIR}/geowebcache-diskquota.xml ]]; then
  cat >>${GEOWEBCACHE_CACHE_DIR}/geowebcache-diskquota.xml <<EOF
<gwcQuotaConfiguration>
  <enabled>true</enabled>
  <cacheCleanUpFrequency>5</cacheCleanUpFrequency>
  <cacheCleanUpUnits>SECONDS</cacheCleanUpUnits>
  <maxConcurrentCleanUps>2</maxConcurrentCleanUps>
  <globalExpirationPolicyName>LFU</globalExpirationPolicyName>
  <globalQuota>
    <value>20</value>
    <units>GiB</units>
  </globalQuota>
 <quotaStore>JDBC</quotaStore>
</gwcQuotaConfiguration>
EOF
fi

if [[ ! -f ${GEOWEBCACHE_CACHE_DIR}/geowebcache-diskquota-jdbc.xml ]]; then
  cat >>${GEOWEBCACHE_CACHE_DIR}/geowebcache-diskquota-jdbc.xml <<EOF
<gwcJdbcConfiguration>
  <dialect>PostgreSQL</dialect>
  <connectionPool>
    <driver>org.postgresql.Driver</driver>
    <url>jdbc:postgresql://${HOST}:${POSTGRES_PORT}/${POSTGRES_DB}</url>
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

function setup_control_flow() {
  cat >"${GEOSERVER_DATA_DIR}"/controlflow.properties <<EOF
timeout=${REQUEST_TIMEOUT}
ows.global=${PARARELL_REQUEST}
ows.wms.getmap=${GETMAP}
ows.wfs.getfeature.application/msexcel=${REQUEST_EXCEL}
user=${SINGLE_USER}
ows.gwc=${GWC_REQUEST}
user.ows.wps.execute=${WPS_REQUEST}
EOF

}

# Function to read env variables from secrets
function file_env {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
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
