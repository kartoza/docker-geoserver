#!/usr/bin/env bash

source /scripts/env-data.sh

export request="wget --progress=bar:force:noscroll -c --no-check-certificate"

random_pass_string=$(openssl rand -base64 15)

function create_dir() {
  DATA_PATH=$1

  if [[ ! -d ${DATA_PATH} ]]; then
    echo "Creating" ${DATA_PATH} "directory"
    mkdir -p ${DATA_PATH}
  fi
}

function remove_files() {
    FILE_PATH=$1
    if [  -f ${FILE_PATH} ]; then
        rm ${FILE_PATH}
    fi

}

function epsg_codes() {
  if [[ ! -f ${GEOSERVER_DATA_DIR}/user_projections/epsg.properties ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/epsg.properties ]]; then
      cp -f ${EXTRA_CONFIG_DIR}/epsg.properties ${GEOSERVER_DATA_DIR}/user_projections/
    else
      # default values
      cp -r ${CATALINA_HOME}/data/user_projections/epsg.properties ${GEOSERVER_DATA_DIR}/epsg.properties
    fi
  fi
}

function web_cors() {
  if [[ ! -f ${CATALINA_HOME}/conf/web.xml ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/web.xml  ]]; then
      cp -f ${EXTRA_CONFIG_DIR}/web.xml  ${CATALINA_HOME}/conf/
    else
      # default values
      cp /build_data/web.xml ${CATALINA_HOME}/conf/
    fi
  fi
}

function tomcat_user_config() {
  if [[ ! -f ${CATALINA_HOME}/conf/tomcat-users.xml ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/tomcat-users.xml ]]; then
      cp -f ${EXTRA_CONFIG_DIR}/tomcat-users.xml ${CATALINA_HOME}/conf/tomcat-users.xml
    else
      # default value
      envsubst < /build_data/tomcat-users.xml > ${CATALINA_HOME}/conf/tomcat-users.xml
    fi
  fi

}
# Helper function to download extensions
function download_extension() {
  URL=$1
  PLUGIN=$2
  OUTPUT_PATH=$3
  if curl --output /dev/null --silent --head --fail "${URL}"; then
    ${request} "${URL}" -O ${OUTPUT_PATH}/${PLUGIN}.zip
  else
    echo "Plugin URL does not exist: ${URL}"
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
  if [[ ! -f ${CLUSTER_CONFIG_DIR}/cluster.properties ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/cluster.properties ]]; then
      cp -f ${EXTRA_CONFIG_DIR}/cluster.properties ${CLUSTER_CONFIG_DIR}/cluster.properties
    else
      # default values
      envsubst < /build_data/cluster.properties > ${CLUSTER_CONFIG_DIR}/cluster.properties
    fi
  fi
}

# Helper function to setup broker config. Used with clustering configs

function broker_config() {
  if [[ ! -f ${CLUSTER_CONFIG_DIR}/embedded-broker.properties ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/embedded-broker.properties ]]; then
      cp -f ${EXTRA_CONFIG_DIR}/embedded-broker.properties ${CLUSTER_CONFIG_DIR}/embedded-broker.properties
    else
      # default values
      envsubst < /build_data/embedded-broker.properties > ${CLUSTER_CONFIG_DIR}/embedded-broker.properties
    fi
  fi
}

# Helper function to configure s3 bucket
function s3_config() {
  if [[ ! -f "${GEOSERVER_DATA_DIR}"/s3.properties ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/s3.properties ]]; then
      cp -f ${EXTRA_CONFIG_DIR}/s3.properties ${GEOSERVER_DATA_DIR}/s3.properties
    else
      # default value
      envsubst < /build_data/s3.properties > ${GEOSERVER_DATA_DIR}/s3.properties
    fi
  fi
}

# Helper function to install plugin in proper path

function install_plugin() {
  DATA_PATH=/community_plugins
  if [ -n "$1" ]; then
    DATA_PATH=$1
  fi
  EXT=$2

  unzip ${DATA_PATH}/${EXT}.zip -d /tmp/gs_plugin
  if [[ -f /geoserver/start.jar ]]; then
    cp -r -u -p /tmp/gs_plugin/*.jar /geoserver/webapps/geoserver/WEB-INF/lib/
  else
    cp -r -u -p /tmp/gs_plugin/*.jar "${CATALINA_HOME}"/webapps/geoserver/WEB-INF/lib/
  fi
  rm -rf /tmp/gs_plugin

}

# Helper function to setup disk quota configs and database configurations

function disk_quota_config() {
  cp /build_data/geowebcache-diskquota.xml ${GEOWEBCACHE_CACHE_DIR}/
  if [[ ! -f ${GEOWEBCACHE_CACHE_DIR}/geowebcache-diskquota-jdbc.xml ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/geowebcache-diskquota-jdbc.xml ]]; then
      cp -f ${EXTRA_CONFIG_DIR}/geowebcache-diskquota-jdbc.xml ${GEOWEBCACHE_CACHE_DIR}/geowebcache-diskquota-jdbc.xml
    else
      # default value
      envsubst < /build_data/geowebcache-diskquota-jdbc.xml > ${GEOWEBCACHE_CACHE_DIR}/geowebcache-diskquota-jdbc.xml
    fi
  fi
}

function setup_control_flow() {
  if [[ ! -f "${GEOSERVER_DATA_DIR}"/controlflow.properties ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/controlflow.properties ]]; then
      cp -f ${EXTRA_CONFIG_DIR}/controlflow.properties "${GEOSERVER_DATA_DIR}"/controlflow.properties
    else
      # default value
      envsubst < /build_data/controlflow.properties > "${GEOSERVER_DATA_DIR}"/controlflow.properties
    fi
  fi

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
