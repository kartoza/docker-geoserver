#!/bin/bash

source /scripts/functions.sh
source /scripts/env-data.sh
GS_VERSION=$(cat /scripts/geoserver_version.txt)
STABLE_PLUGIN_BASE_URL=$(cat /scripts/geoserver_gs_url.txt)

web_cors

# install Font files in resources/fonts if they exists
if ls "${FONTS_DIR}"/*.ttf >/dev/null 2>&1; then
  cp -rf "${FONTS_DIR}"/*.ttf /usr/share/fonts/truetype/
fi

# Install opentype fonts
if ls "${FONTS_DIR}"/*.otf >/dev/null 2>&1; then
  cp -rf "${FONTS_DIR}"/*.otf /usr/share/fonts/opentype/
fi

# Activate sample data
DATA_INIT_LOCK=${EXTRA_CONFIG_DIR}/.init_data.lock
if [[ ! -f ${DATA_INIT_LOCK} ]];then
  if [[ ${SAMPLE_DATA} =~ [Tt][Rr][Uu][Ee] ]]; then
    cp -r "${CATALINA_HOME}"/data/* "${GEOSERVER_DATA_DIR}"
  fi
  touch ${DATA_INIT_LOCK}
fi

# Recreate DISK QUOTA config, useful to change between H2 and jdbc and change connection or schema
if [[ "${RECREATE_DISKQUOTA}" =~ [Tt][Rr][Uu][Ee] ]]; then
  if [[ -f "${GEOWEBCACHE_CACHE_DIR}"/geowebcache-diskquota.xml ]]; then
    rm "${GEOWEBCACHE_CACHE_DIR}"/geowebcache-diskquota.xml
  fi
  if [[ -f "${GEOWEBCACHE_CACHE_DIR}"/geowebcache-diskquota-jdbc.xml ]]; then
    rm "${GEOWEBCACHE_CACHE_DIR}"/geowebcache-diskquota-jdbc.xml
  fi
fi

export DISK_QUOTA_FREQUENCY DISK_QUOTA_SIZE
if [[  ${DB_BACKEND} =~ [Pp][Oo][Ss][Tt][Gg][Rr][Ee][Ss] ]]; then
  postgres_ssl_setup
  export DISK_QUOTA_BACKEND=JDBC
  export SSL_PARAMETERS=${PARAMS}
  default_disk_quota_config
  jdbc_disk_quota_config

  echo -e "[Entrypoint] Checking PostgreSQL connection to see if diskquota tables are loaded: \033[0m"
  export PGPASSWORD="${POSTGRES_PASS}"
  postgres_ready_status ${HOST} ${POSTGRES_PORT} ${POSTGRES_USER} $POSTGRES_DB
  create_gwc_tile_tables ${HOST} ${POSTGRES_PORT} ${POSTGRES_USER} $POSTGRES_DB $POSTGRES_SCHEMA
else
  export DISK_QUOTA_BACKEND=H2
  default_disk_quota_config
fi

# GWC Global Config options GeoServer WMS
export WMS_DIR_INTEGRATION REQUIRE_TILED_PARAMETER WMSC_ENABLED TMS_ENABLED SECURITY_ENABLED
activate_gwc_global_configs


# Install stable plugins
if [[ ! -z "${STABLE_EXTENSIONS}" ]]; then
  if  [[ ${FORCE_DOWNLOAD_STABLE_EXTENSIONS} =~ [Tt][Rr][Uu][Ee] ]];then
      rm -rf /stable_plugins/*.zip
      for plugin in $(cat /stable_plugins/stable_plugins.txt); do
        approved_plugins_url="${STABLE_PLUGIN_BASE_URL}/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-${plugin}.zip"
        download_extension "${approved_plugins_url}" "${plugin}" /stable_plugins
      done
      for ext in $(echo "${STABLE_EXTENSIONS}" | tr ',' ' '); do
        install_plugin /stable_plugins/ "${ext}"
    done
  else
    for ext in $(echo "${STABLE_EXTENSIONS}" | tr ',' ' '); do
        if [[ ! -f /stable_plugins/${ext}.zip ]]; then
          approved_plugins_url="${STABLE_PLUGIN_BASE_URL}/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-${ext}.zip"
          download_extension "${approved_plugins_url}" "${ext}" /stable_plugins/
          install_plugin /stable_plugins/ "${ext}"
        else
          install_plugin /stable_plugins/ "${ext}"
        fi

    done
  fi
fi


# Function to install community extensions
export S3_SERVER_URL S3_USERNAME S3_PASSWORD
# Pass an additional startup argument i.e -Ds3.properties.location=${GEOSERVER_DATA_DIR}/s3.properties
s3_config


# Install community modules plugins
if [[ ! -z ${COMMUNITY_EXTENSIONS} ]]; then
  if  [[ ${FORCE_DOWNLOAD_COMMUNITY_EXTENSIONS} =~ [Tt][Rr][Uu][Ee] ]];then
    rm -rf /community_plugins/*.zip
    for plugin in $(cat /community_plugins/community_plugins.txt); do
      community_plugins_url="https://build.geoserver.org/geoserver/${GS_VERSION:0:5}x/community-latest/geoserver-${GS_VERSION:0:4}-SNAPSHOT-${plugin}.zip"
      download_extension "${community_plugins_url}" "${plugin}" /community_plugins
    done
    for ext in $(echo "${COMMUNITY_EXTENSIONS}" | tr ',' ' '); do
        install_plugin /community_plugins "${ext}"
    done
  else
    for ext in $(echo "${COMMUNITY_EXTENSIONS}" | tr ',' ' '); do
        if [[ ! -f /community_plugins/${ext}.zip ]]; then
          community_plugins_url="https://build.geoserver.org/geoserver/${GS_VERSION:0:5}x/community-latest/geoserver-${GS_VERSION:0:4}-SNAPSHOT-${ext}.zip"
          download_extension "${community_plugins_url}" "${ext}" /community_plugins
          install_plugin /community_plugins "${ext}"
        else
          install_plugin /community_plugins "${ext}"
        fi
    done
  fi
fi

export REQUEST_TIMEOUT PARALLEL_REQUEST GETMAP REQUEST_EXCEL SINGLE_USER GWC_REQUEST WPS_REQUEST
# Setup control flow properties
setup_control_flow

if [[ "${TOMCAT_EXTRAS}" =~ [Tt][Rr][Uu][Ee] ]]; then
    delete_file "${CATALINA_HOME}"/conf/tomcat-users.xml
    unzip -qq /tomcat_apps.zip -d /tmp/
    cp -r  /tmp/tomcat_apps/webapps.dist/* "${CATALINA_HOME}"/webapps/
    rm -r /tmp/tomcat_apps
    if [[ ${POSTGRES_JNDI} =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
      if [[ -f ${EXTRA_CONFIG_DIR}/context.xml  ]]; then
        envsubst < ${EXTRA_CONFIG_DIR}/context.xml > "${CATALINA_HOME}"/webapps/manager/META-INF/context.xml
      else
        cp /build_data/context.xml "${CATALINA_HOME}"/webapps/manager/META-INF/
        sed -i -e '19,36d' "${CATALINA_HOME}"/webapps/manager/META-INF/context.xml
      fi
    fi
    if [[ -z ${TOMCAT_PASSWORD} ]]; then
        generate_random_string 18
        export TOMCAT_PASSWORD=${RAND}
        echo $TOMCAT_PASSWORD >${GEOSERVER_DATA_DIR}/security/tomcat_pass.txt
        if [[ ${SHOW_PASSWORD} =~ [Tt][Rr][Uu][Ee] ]];then
          echo -e "[Entrypoint] GENERATED tomcat  PASSWORD: \e[1;31m $TOMCAT_PASSWORD \033[0m"
        fi
    else
       export TOMCAT_PASSWORD=${TOMCAT_PASSWORD}
    fi
    # Setup tomcat apps manager
    export TOMCAT_USER
    tomcat_user_config
else
    delete_folder "${CATALINA_HOME}"/webapps/ROOT &&
    delete_folder "${CATALINA_HOME}"/webapps/docs &&
    delete_folder "${CATALINA_HOME}"/webapps/examples &&
    delete_folder "${CATALINA_HOME}"/webapps/host-manager &&
    delete_folder "${CATALINA_HOME}"/webapps/manager

    if [[ "${ROOT_WEBAPP_REDIRECT}" =~ [Tt][Rr][Uu][Ee] ]]; then
        create_dir "${CATALINA_HOME}"/webapps/ROOT
        cat /build_data/index.jsp | sed "s@/geoserver/@/${GEOSERVER_CONTEXT_ROOT}/@g" > "${CATALINA_HOME}"/webapps/ROOT/index.jsp
    fi
fi

if [[ -z "${EXISTING_DATA_DIR}" ]]; then
  /usr/local/tomcat/tmp/update_passwords.sh
fi