#!/usr/bin/env bash


export request="wget --progress=bar:force:noscroll -c --tries=2 "

function log() {
    echo "$0:${BASH_LINENO[*]}": $@
}

function validate_url(){
  EXTRA_PARAMS=''
  if [ -n "$2" ]; then
    EXTRA_PARAMS=$2
  fi
  if [[ `wget -S --spider $1  2>&1 | grep 'HTTP/1.1 200 OK'` ]]; then
    ${request} $1 $2
  else
    echo -e "URL : \e[1;31m $1 does not exists \033[0m"
  fi
}


function generate_random_string() {
  STRING_LENGTH=$1
  random_pass_string=$(cat /dev/urandom | tr -dc '[:alnum:]' | head -c "${STRING_LENGTH}")
  if [[ ! -f ${EXTRA_CONFIG_DIR}/.pass_${STRING_LENGTH}.txt ]]; then
    echo "${random_pass_string}" > "${EXTRA_CONFIG_DIR}"/.pass_"${STRING_LENGTH}".txt
  fi
  export RAND=$(cat "${EXTRA_CONFIG_DIR}"/.pass_"${STRING_LENGTH}".txt)
}


function create_dir() {
  DATA_PATH=$1

  if [[ ! -d ${DATA_PATH} ]]; then
    echo "Creating" "${DATA_PATH}" "directory"
    mkdir -p "${DATA_PATH}"
  fi
}

function delete_file() {
    FILE_PATH=$1
    if [  -f "${FILE_PATH}" ]; then
        rm "${FILE_PATH}"
    fi

}

function delete_folder() {
    FOLDER_PATH=$1
    if [  -d "${FOLDER_PATH}" ]; then
        rm -r "${FOLDER_PATH}"
    fi

}


# Function to add custom crs in geoserver data directory
# https://docs.geoserver.org/latest/en/user/configuration/crshandling/customcrs.html
function setup_custom_crs() {
  if [[ ! -f ${GEOSERVER_DATA_DIR}/user_projections/epsg.properties ]]; then
    # If it doesn't exists, copy from ${EXTRA_CONFIG_DIR} directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/epsg.properties ]]; then
      cp -f "${EXTRA_CONFIG_DIR}"/epsg.properties "${GEOSERVER_DATA_DIR}"/user_projections/
    else
      # default values
      cp -r "${CATALINA_HOME}"/data/user_projections/epsg.properties "${GEOSERVER_DATA_DIR}"/user_projections/epsg.properties
    fi
  fi
}

# Function to enable cors support thought tomcat
# https://documentation.bonitasoft.com/bonita/2021.1/enable-cors-in-tomcat-bundle
function web_cors() {
  if [[ ! -f ${CATALINA_HOME}/conf/web.xml ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/web.xml  ]]; then
      cp -f "${EXTRA_CONFIG_DIR}"/web.xml  "${CATALINA_HOME}"/conf/
    else
      # default values
      cp /build_data/web.xml "${CATALINA_HOME}"/conf/
    fi
  fi
}

# Function to add users when tomcat manager is configured
# https://tomcat.apache.org/tomcat-8.0-doc/manager-howto.html
function tomcat_user_config() {
  if [[ ! -f ${CATALINA_HOME}/conf/tomcat-users.xml ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/tomcat-users.xml ]]; then
      envsubst < "${EXTRA_CONFIG_DIR}"/tomcat-users.xml > "${CATALINA_HOME}"/conf/tomcat-users.xml
    else
      # default value
      envsubst < /build_data/tomcat-users.xml > "${CATALINA_HOME}"/conf/tomcat-users.xml
    fi
  fi

}
# Helper function to download extensions
function download_extension() {
  URL=$1
  PLUGIN=$2
  OUTPUT_PATH=$3
  if curl --output /dev/null --silent --head --fail "${URL}"; then
    ${request} "${URL}" -O "${OUTPUT_PATH}"/"${PLUGIN}".zip
  else
    echo -e "Plugin URL does not exist:: \e[1;31m ${URL} \033[0m"
  fi

}

# A little logic that will fetch the geoserver war zip file if it is not available locally in the resources dir
function download_geoserver() {

if [[ ! -f /tmp/resources/geoserver-${GS_VERSION}.zip ]]; then
    if [[ "${WAR_URL}" == *\.zip ]]; then
      destination=/tmp/resources/geoserver-${GS_VERSION}.zip
      ${request} "${WAR_URL}" -O "${destination}"
      unzip /tmp/resources/geoserver-"${GS_VERSION}".zip -d /tmp/geoserver
    else
      destination=/tmp/geoserver/geoserver.war
      mkdir -p /tmp/geoserver/ &&
      ${request} "${WAR_URL}" -O ${destination}
    fi
else
  unzip /tmp/resources/geoserver-"${GS_VERSION}".zip -d /tmp/geoserver
fi

}

# Helper function to setup cluster config for the clustering plugin
# https://docs.geoserver.org/stable/en/user/community/jms-cluster/index.html
function cluster_config() {
  if [[ ! -f ${CLUSTER_CONFIG_DIR}/cluster.properties ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/cluster.properties ]]; then
      envsubst < "${EXTRA_CONFIG_DIR}"/cluster.properties > "${CLUSTER_CONFIG_DIR}"/cluster.properties
    else
      # default values
      envsubst < /build_data/cluster.properties > "${CLUSTER_CONFIG_DIR}"/cluster.properties
    fi
  fi
}

# Helper function to setup broker config. Used with clustering configs
# https://docs.geoserver.org/stable/en/user/community/jms-cluster/index.html

function broker_config() {
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

function broker_xml_config() {
  if [[ ! -f ${CLUSTER_CONFIG_DIR}/broker.xml ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/broker.xml ]]; then
      envsubst < "${EXTRA_CONFIG_DIR}"/broker.xml > "${CLUSTER_CONFIG_DIR}"/broker.xml
    else
      # default values
      if [[  ${DB_BACKEND} =~ [Pp][Oo][Ss][Tt][Gg][Rr][Ee][Ss] ]]; then
        envsubst < /build_data/broker.xml > "${CLUSTER_CONFIG_DIR}"/broker.xml
        sed -i -e '11,13d' "${CLUSTER_CONFIG_DIR}"/broker.xml
      else
        envsubst < /build_data/broker.xml > "${CLUSTER_CONFIG_DIR}"/broker.xml
        sed -i -e '15,26d' ${CLUSTER_CONFIG_DIR}/broker.xml
      fi
    fi
  fi
}

# Helper function to configure s3 bucket
# https://docs.geoserver.org/latest/en/user/community/s3-geotiff/index.html
function s3_config() {
  if [[ ! -f "${GEOSERVER_DATA_DIR}"/s3.properties ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/s3.properties ]]; then
      envsubst < "${EXTRA_CONFIG_DIR}"/s3.properties > "${GEOSERVER_DATA_DIR}"/s3.properties
    else
      # default value
      envsubst < /build_data/s3.properties > "${GEOSERVER_DATA_DIR}"/s3.properties
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

  if [[ -f "${DATA_PATH}"/"${EXT}".zip ]];then
     unzip "${DATA_PATH}"/"${EXT}".zip -d /tmp/gs_plugin
     if [[ -f /geoserver/start.jar ]]; then
       cp -r -u -p /tmp/gs_plugin/*.jar /geoserver/webapps/geoserver/WEB-INF/lib/
     else
       cp -r -u -p /tmp/gs_plugin/*.jar "${CATALINA_HOME}"/webapps/geoserver/WEB-INF/lib/
     fi
     rm -rf /tmp/gs_plugin
  else
    echo -e "\e[32m ${EXT} extension will not be installed because it is not available \033[0m"
 fi
}

# Helper function to setup disk quota configs and database configurations

function default_disk_quota_config() {
  if [[ ! -f "${GEOWEBCACHE_CACHE_DIR}"/geowebcache-diskquota.xml ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f "${EXTRA_CONFIG_DIR}"/geowebcache-diskquota.xml ]]; then
      envsubst < "${EXTRA_CONFIG_DIR}"/geowebcache-diskquota.xml > "${GEOWEBCACHE_CACHE_DIR}"/geowebcache-diskquota.xml
    else
      # default value
      envsubst < /build_data/geowebcache-diskquota.xml > "${GEOWEBCACHE_CACHE_DIR}"/geowebcache-diskquota.xml
    fi
  fi
}

function jdbc_disk_quota_config() {

  if [[ ! -f ${GEOWEBCACHE_CACHE_DIR}/geowebcache-diskquota-jdbc.xml ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/geowebcache-diskquota-jdbc.xml ]]; then
      envsubst < "${EXTRA_CONFIG_DIR}"/geowebcache-diskquota-jdbc.xml < "${GEOWEBCACHE_CACHE_DIR}"/geowebcache-diskquota-jdbc.xml
    else
      # default value
      envsubst < /build_data/geowebcache-diskquota-jdbc.xml > "${GEOWEBCACHE_CACHE_DIR}"/geowebcache-diskquota-jdbc.xml
    fi
  fi
}

# Function to setup control flow https://docs.geoserver.org/stable/en/user/extensions/controlflow/index.html
function setup_control_flow() {
  if [[ ! -f "${GEOSERVER_DATA_DIR}"/controlflow.properties ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f "${EXTRA_CONFIG_DIR}"/controlflow.properties ]]; then
      envsubst < "${EXTRA_CONFIG_DIR}"/controlflow.properties > "${GEOSERVER_DATA_DIR}"/controlflow.properties
    else
      # default value
      envsubst < /build_data/controlflow.properties > "${GEOSERVER_DATA_DIR}"/controlflow.properties
    fi
  fi

}

function setup_logging() {
  if [[ ! -f "${CATALINA_HOME}"/log4j.properties ]]; then
    # If it doesn't exists, copy from ${EXTRA_CONFIG_DIR} directory if exists
    if [[ -f "${EXTRA_CONFIG_DIR}"/log4j.properties ]]; then
      envsubst < "${EXTRA_CONFIG_DIR}"/log4j.properties > "${CATALINA_HOME}"/log4j.properties
    else
      # default value
      envsubst < /build_data/log4j.properties > "${CATALINA_HOME}"/log4j.properties
    fi
  fi

}

function geoserver_logging() {

  if [[ ! -f ${GEOSERVER_DATA_DIR}/logging.xml ]];then
    echo "
<logging>
  <level>${GEOSERVER_LOG_LEVEL}</level>
  <location>logs/geoserver.log</location>
  <stdOutLogging>true</stdOutLogging>
</logging>
" > "${GEOSERVER_DATA_DIR}"/logging.xml

  fi
  if [[ ! -f ${GEOSERVER_DATA_DIR}/logs/geoserver.log ]];then
    touch "${GEOSERVER_DATA_DIR}"/logs/geoserver.log
  fi
}

# Function to read env variables from secrets
function file_env {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${1:-}"
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

# Credits to https://github.com/korkin25 from https://github.com/kartoza/docker-geoserver/pull/371
function set_vars() {
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


  CLUSTER_CONFIG_DIR="${GEOSERVER_DATA_DIR}/cluster/instance_${RANDOM_STRING}"
  MONITOR_AUDIT_PATH="${GEOSERVER_DATA_DIR}/monitoring/monitor_${RANDOM_STRING}"
  CLUSTER_LOCKFILE="${CLUSTER_CONFIG_DIR}/.cluster.lock"
}




function postgres_ssl_setup() {
  if [[ ${SSL_MODE} == 'verify-ca' || ${SSL_MODE} == 'verify-full' ]]; then
        if [[ -z ${SSL_CERT_FILE} || -z ${SSL_KEY_FILE} || -z ${SSL_CA_FILE} ]]; then
                exit 0
        else
          export PARAMS="sslmode=${SSL_MODE}&sslcert=${SSL_CERT_FILE}&sslkey=${SSL_KEY_FILE}&sslrootcert=${SSL_CA_FILE}"
        fi
  elif [[ ${SSL_MODE} == 'disable' || ${SSL_MODE} == 'allow' || ${SSL_MODE} == 'prefer' || ${SSL_MODE} == 'require' ]]; then
       export PARAMS="sslmode=${SSL_MODE}"
  fi

}


function make_hash(){
    NEW_PASSWORD=$1
    GEO_INSTALL_PATH=$2
    ALGO_TYPE=$3
    (echo "digest1:" && java -classpath $(find $GEO_INSTALL_PATH -regex ".*jasypt-[0-9]\.[0-9]\.[0-9].*jar") org.jasypt.intf.cli.JasyptStringDigestCLI digest.sh algorithm=$ALGO_TYPE saltSizeBytes=16 iterations=100000 input="$NEW_PASSWORD" verbose=0) | tr -d '\n'
}
