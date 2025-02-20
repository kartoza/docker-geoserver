#!/usr/bin/env bash

function log() {
    echo "$0:${BASH_LINENO[*]}": $@
}

function generate_random_string() {
  STRING_LENGTH=$1
  random_pass_string=$(cat /dev/urandom | tr -dc '[:alnum:]' | head -c "${STRING_LENGTH}")
  if [[ ! -f ${EXTRA_CONFIG_DIR}/.pass_${STRING_LENGTH}.txt ]]; then
    echo "${random_pass_string}" > "${EXTRA_CONFIG_DIR}"/.pass_"${STRING_LENGTH}".txt
  fi
  RAND=$(cat "${EXTRA_CONFIG_DIR}"/.pass_"${STRING_LENGTH}".txt)
  export RAND
}


function create_dir() {
  DATA_PATH=$1

  if [[ ! -d ${DATA_PATH} ]]; then
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
    # If it exists, copy from ${EXTRA_CONFIG_DIR} directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/epsg.properties ]]; then
       cp -f "${EXTRA_CONFIG_DIR}"/epsg.properties "${GEOSERVER_DATA_DIR}"/user_projections/
    else
      # default values
      if [[ ! -f ${GEOSERVER_DATA_DIR}/user_projections/epsg.properties ]]; then
        cp -r "${CATALINA_HOME}"/data/user_projections/epsg.properties "${GEOSERVER_DATA_DIR}"/user_projections/epsg.properties
      fi
    fi
}

function setup_custom_override_crs() {
    # If it doesn't exists, copy from ${EXTRA_CONFIG_DIR} directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/epsg_overrides.properties ]]; then
      cp -f "${EXTRA_CONFIG_DIR}"/epsg_overrides.properties "${GEOSERVER_DATA_DIR}"/user_projections/
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
      envsubst < /build_data/web.xml > "${CATALINA_HOME}"/conf/web.xml
      ###
      # Deactivate CORS filter in web.xml if DISABLE_CORS=true
      # Useful if CORS is handled outside of Tomcat (e.g. in a proxying webserver like nginx)
      ###
      if [[ "${DISABLE_CORS}" =~ [Tt][Rr][Uu][Ee] ]]; then
        sed -i 's/<!-- CORS_START.*/<!-- CORS DEACTIVATED BY DISABLE_CORS -->\n<!--/; s/^.*<!-- CORS_END -->/-->/' \
          "${CATALINA_HOME}"/conf/web.xml
      fi
      ###
      # Deactivate security filter in web.xml if DISABLE_SECURITY_FILTER=true
      # https://github.com/kartoza/docker-geoserver/issues/549
      ###
      if [[ "${DISABLE_SECURITY_FILTER}" =~ [Tt][Rr][Uu][Ee] ]]; then
        sed -i 's/<!-- SECURITY_START.*/<!-- SECURITY FILTER DEACTIVATED BY DISABLE_SECURITY_FILTER -->\n<!--/; s/^.*<!-- SECURITY_END -->/-->/' \
          "${CATALINA_HOME}"/conf/web.xml
      fi
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
  curl --progress-bar -fLvo "${OUTPUT_PATH}/${PLUGIN}.zip" "${URL}"
}

function validate_geo_install() {
  DATA_PATH=$1
  # Check if geoserver is installed early so that we can fail early on
  if [[ $(ls -A "${DATA_PATH}")  ]]; then
     echo -e "\e[32m  GeoServer install dir exist proceed with install \033[0m"
  else
    echo -e "\e[32m  GeoServer install dir does not exist, exiting \033[0m"
    exit 1
  fi

}

function detect_install_dir() {
  if [[ -f ${GEOSERVER_HOME}/start.jar ]]; then
    echo "${GEOSERVER_HOME}"
  else
    echo "${CATALINA_HOME}"
  fi
}

function unzip_geoserver() {
  if [[ -f /tmp/geoserver/geoserver.war ]]; then
    unzip /tmp/geoserver/geoserver.war -d "${CATALINA_HOME}"/webapps/"${GEOSERVER_CONTEXT_ROOT}"
    validate_geo_install "${CATALINA_HOME}"/webapps/"${GEOSERVER_CONTEXT_ROOT}"
    cp -r "${CATALINA_HOME}"/webapps/"${GEOSERVER_CONTEXT_ROOT}"/data "${CATALINA_HOME}"
    mv "${CATALINA_HOME}"/data/security "${CATALINA_HOME}"
    rm -rf "${CATALINA_HOME}"/webapps/"${GEOSERVER_CONTEXT_ROOT}"/data
    mv "${CATALINA_HOME}"/webapps/"${GEOSERVER_CONTEXT_ROOT}"/WEB-INF/lib/postgresql-* "${CATALINA_HOME}"/postgres_config/
    rm -rf /tmp/geoserver
else
    cp -r /tmp/geoserver/* "${GEOSERVER_HOME}"/ && \
    validate_geo_install "${GEOSERVER_HOME}"/ && \
    cp -r "${GEOSERVER_HOME}"/data_dir "${CATALINA_HOME}"/data &&
    mv "${CATALINA_HOME}"/data/security "${CATALINA_HOME}"
fi

}

# A little logic that will fetch the geoserver war zip file if it is not available locally in the resources dir
function package_geoserver() {
  # Check if resource file exists otherwise use the default downloaded
  if [[  -f /tmp/resources/geoserver-${GS_VERSION}.zip ]];then
    unzip /tmp/resources/geoserver-"${GS_VERSION}".zip -d /tmp/geoserver && \
    unzip_geoserver
  elif [[  -f /tmp/resources/geoserver-${GS_VERSION}-bin.zip  ]];then
    unzip /tmp/resources/geoserver-"${GS_VERSION}".zip -d /tmp/geoserver && \
    unzip_geoserver
  elif [[  -f /tmp/resources/geoserver.war  ]];then
    mkdir -p /tmp/geoserver
    cp /tmp/resources/geoserver.war /tmp/geoserver/geoserver.war
    unzip_geoserver
  else
    if [[ -f ${REQUIRED_PLUGINS_DIR}/geoserver.zip ]]; then
      unzip ${REQUIRED_PLUGINS_DIR}/geoserver.zip -d /tmp/geoserver && \
      unzip_geoserver
    elif [[ -f ${REQUIRED_PLUGINS_DIR}/geoserver.war ]]; then
      mkdir /tmp/geoserver
      cp ${REQUIRED_PLUGINS_DIR}/geoserver.war /tmp/geoserver
      unzip_geoserver
    else
      echo "GeoServer bin/war file missing, exiting installation"
      exit 1
    fi
  fi
}


# Helper function to setup cluster config for the clustering plugin
# https://docs.geoserver.org/stable/en/user/community/jms-cluster/index.html
function cluster_config() {
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


function broker_config() {
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

function broker_xml_config() {
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

function s3_config() {
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

function install_plugin() {
  DATA_PATH=/community_plugins
  if [ -n "$1" ]; then
    DATA_PATH=$1
  fi
  EXT=$2

  if [[ -f "${DATA_PATH}/${EXT}.zip" ]]; then
     unzip -qq "${DATA_PATH}/${EXT}.zip" -d /tmp/gs_plugin
     echo -e "\e[32m [Entrypoint] Enabling extension :\033[0m \e[1;31m ${EXT} \033[0m"
     GEOSERVER_INSTALL_DIR="$(detect_install_dir)"
     cp -r -u -p /tmp/gs_plugin/*.jar "${GEOSERVER_INSTALL_DIR}/webapps/${GEOSERVER_CONTEXT_ROOT}/WEB-INF/lib/"
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

  if [[ ! -f "${GEOWEBCACHE_CACHE_DIR}"/geowebcache-diskquota-jdbc.xml ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f "${EXTRA_CONFIG_DIR}"/geowebcache-diskquota-jdbc.xml ]]; then
      envsubst < "${EXTRA_CONFIG_DIR}"/geowebcache-diskquota-jdbc.xml > "${GEOWEBCACHE_CACHE_DIR}"/geowebcache-diskquota-jdbc.xml
    else
      # default value
      envsubst < /build_data/geowebcache-diskquota-jdbc.xml > "${GEOWEBCACHE_CACHE_DIR}"/geowebcache-diskquota-jdbc.xml
    fi
  fi
}

function activate_gwc_global_configs() {
  if [[ ! -f "${GEOSERVER_DATA_DIR}"/gwc-gs.xml ]]; then
    if [[ -f "${EXTRA_CONFIG_DIR}"/gwc-gs.xml ]]; then
      envsubst < "${EXTRA_CONFIG_DIR}"/gwc-gs.xml > "${GEOSERVER_DATA_DIR}"/gwc-gs.xml
    else
      # default value
      envsubst < /build_data/gwc-gs.xml > "${GEOSERVER_DATA_DIR}"/gwc-gs.xml
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

function log4j_logging() {
  if [[ ! -f "${CATALINA_HOME}"/log4j.properties ]]; then
    # If it doesn't exists, copy from ${EXTRA_CONFIG_DIR} directory if exists
    if [[ -f "${EXTRA_CONFIG_DIR}"/log4j.properties ]]; then
      envsubst < "${EXTRA_CONFIG_DIR}"/log4j.properties > "${CATALINA_HOME}"/log4j.properties
    else
      # default value
      if [[ ${CLUSTERING} =~ [Tt][Rr][Uu][Ee] ]]; then
        export LOG_PATH=${CLUSTER_CONFIG_DIR}/geoserver-${HOSTNAME}.log
      else
        export LOG_PATH=${GEOSERVER_LOG_DIR}/geoserver.log
      fi
      envsubst < /build_data/log4j.properties > "${CATALINA_HOME}"/log4j.properties
    fi
  fi

}

function geoserver_logging() {
  if [[ ${CLUSTERING} =~ [Tt][Rr][Uu][Ee] ]]; then
      export LOG_PATH=${CLUSTER_CONFIG_DIR}/geoserver-${HOSTNAME}.log
    else
      create_dir "${GEOSERVER_LOG_DIR}"
      export LOG_PATH=${GEOSERVER_LOG_DIR}/geoserver.log
  fi

    echo "
<logging>
  <level>${GEOSERVER_LOG_PROFILE}</level>
  <location>${LOG_PATH}</location>
  <stdOutLogging>true</stdOutLogging>
</logging>
" > "${GEOSERVER_DATA_DIR}"/logging.xml

  if [[ ! -f ${LOG_PATH} ]];then
    touch "${LOG_PATH}"
  fi
}


function tomcat_logging() {
  # If it doesn't exists, copy from /settings directory if exists
  if [[ -f "${EXTRA_CONFIG_DIR}"/logging.properties ]]; then
    envsubst < "${EXTRA_CONFIG_DIR}"/logging.properties > "${CATALINA_HOME}"/conf/logging.properties
  else
    # default value
    envsubst < /build_data/logging.properties > "${CATALINA_HOME}"/conf/logging.properties
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
  if [[ ${EMBEDDED_BROKER} == 'disabled' ]];then
    CLUSTER_NAME=node
  else
    CLUSTER_NAME=master
  fi
  CLUSTER_CONFIG_DIR="${GEOSERVER_DATA_DIR}/cluster/${CLUSTER_NAME}/instance_${RANDOM_STRING}"
  MONITOR_AUDIT_PATH="${GEOSERVER_DATA_DIR}/monitoring/monitor_${RANDOM_STRING}"
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
    (echo "digest1:" && java -classpath $(find "${GEO_INSTALL_PATH}" -regex ".*jasypt-[0-9]\.[0-9]\.[0-9].*jar") org.jasypt.intf.cli.JasyptStringDigestCLI digest.sh algorithm=$ALGO_TYPE saltSizeBytes=16 iterations=100000 input="$NEW_PASSWORD" verbose=0) | tr -d '\n'
}

function postgres_ready_status() {
  HOST="$1"
  PORT="$2"
  USER="$3"
  DB="$4"
  until psql -h "$HOST" -p "$PORT" -U "$USER" -d "$DB"  -c '\dt public.spatial_ref_sys' >/dev/null 2>&1; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 1
done
}

function create_gwc_tile_tables(){
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

function gwc_file_perms() {
  GEO_USER_PERM=$(stat -c '%U' "${GEOSERVER_DATA_DIR}")
  GEO_GRP_PERM=$(stat -c '%G' "${GEOSERVER_DATA_DIR}")
  GWC_USER_PERM=$(stat -c '%U' "${GEOWEBCACHE_CACHE_DIR}")
  GWC_GRP_PERM=$(stat -c '%G' "${GEOWEBCACHE_CACHE_DIR}")
  case "${GEOWEBCACHE_CACHE_DIR}" in ${GEOSERVER_DATA_DIR}/*)
    echo -e " \e[32m [Entrypoint] \033[0m \e[1;31m ${GEOWEBCACHE_CACHE_DIR} \033[0m \e[32m is nested in \033[0m \e[1;31m ${GEOSERVER_DATA_DIR} \033[0m"
    if [[ ${CHOWN_DATA_DIR} =~ [Tt][Rr][Uu][Ee] ]];then
      if [[ ${GEO_USER_PERM} != "${USER_NAME}" ]] &&  [[ ${GEO_GRP_PERM} != "${GEO_GROUP_NAME}"  ]];then
        echo -e "\e[32m [Entrypoint] Changing folder permission for:\033[0m \e[1;31m ${GEOSERVER_DATA_DIR} \033[0m"
        chown -R "${USER_NAME}":"${GEO_GROUP_NAME}" "${GEOSERVER_DATA_DIR}"
      fi
    fi
    ;;
  *)
    echo -e "\e[1;31m ${GEOWEBCACHE_CACHE_DIR} \033[0m is not nested in \e[1;31m ${GEOSERVER_DATA_DIR} \033[0m"
    if [[ ${CHOWN_DATA_DIR} =~ [Tt][Rr][Uu][Ee] ]];then
      if [[ ${GEO_USER_PERM} != "${USER_NAME}" ]] &&  [[ ${GEO_GRP_PERM} != "${GEO_GROUP_NAME}"  ]];then
        echo -e "\e[32m [Entrypoint] Changing folder permission for:\033[0m \e[1;31m ${GEOSERVER_DATA_DIR} \033[0m"
        chown -R "${USER_NAME}":"${GEO_GROUP_NAME}" "${GEOSERVER_DATA_DIR}"
      fi
    fi
    if [[ ${CHOWN_GWC_DATA_DIR} =~ [Tt][Rr][Uu][Ee] ]];then
      if [[ ${GWC_USER_PERM} != "${USER_NAME}" ]] &&  [[ ${GWC_GRP_PERM} != "${GEO_GROUP_NAME}"  ]];then
        echo -e "\e[32m [Entrypoint] Changing folder permission for:\033[0m \e[1;31m ${GEOWEBCACHE_CACHE_DIR} \033[0m"
        chown -R "${USER_NAME}":"${GEO_GROUP_NAME}" "${GEOWEBCACHE_CACHE_DIR}"
      fi
    fi
   ;;
esac

}

function entry_point_script {

  if find "/docker-entrypoint-geoserver.d" -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
    for f in /docker-entrypoint-geoserver.d/*; do
      case "$f" in
            *.sh)     echo "$0: running $f"; . "$f" || true;;
            *)        echo "$0: ignoring $f" ;;
        esac
        echo
    done
  fi
}

function setup_monitoring() {

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

function setup_jdbc_db_config() {
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


function setup_jdbc_db_store() {
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

function setup_hz_cluster() {
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