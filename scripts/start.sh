#!/bin/bash

source /scripts/functions.sh
source /scripts/env-data.sh
GS_VERSION=$(cat /scripts/geoserver_version.txt)

# install Font files in resources/fonts if they exists
if ls "${FONTS_DIR}"/*.ttf >/dev/null 2>&1; then
  cp -rf "${FONTS_DIR}"/*.ttf /usr/share/fonts/truetype/
fi

# Install opentype fonts
if ls "${FONTS_DIR}"/*.otf >/dev/null 2>&1; then
  cp -rf "${FONTS_DIR}"/*.otf /usr/share/fonts/opentype/
fi

# Add custom espg properties file or the default one
create_dir "${GEOSERVER_DATA_DIR}"/user_projections
create_dir "${GEOWEBCACHE_CACHE_DIR}"

create_dir "${GEOSERVER_DATA_DIR}"/logs
export GEOSERVER_LOG_LEVEL
geoserver_logging

# Activate sample data
DATA_INIT_LOCK=${EXTRA_CONFIG_DIR}/.init_data.lock
if [[ ! -f ${DATA_INIT_LOCK} ]];then
  if [[ ${SAMPLE_DATA} =~ [Tt][Rr][Uu][Ee] ]]; then
    cp -r "${CATALINA_HOME}"/data/* "${GEOSERVER_DATA_DIR}"
  fi
  touch ${DATA_INIT_LOCK}
fi



export DISK_QUOTA_SIZE
if [[  ${DB_BACKEND} =~ [Pp][Oo][Ss][Tt][Gg][Rr][Ee][Ss] ]]; then
  postgres_ssl_setup
  export DISK_QUOTA_BACKEND=JDBC
  export SSL_PARAMETERS=${PARAMS}
  default_disk_quota_config
  jdbc_disk_quota_config
else
  export DISK_QUOTA_BACKEND=H2
  default_disk_quota_config

fi



# Install stable plugins
if [[ -z "${STABLE_EXTENSIONS}" ]]; then
  echo -e "\e[32m STABLE_EXTENSIONS is unset, so we do not install any stable extensions \033[0m"
else
  if  [[ ${FORCE_DOWNLOAD_STABLE_EXTENSIONS} =~ [Tt][Rr][Uu][Ee] ]];then
      rm -rf /stable_plugins/*.zip
      for plugin in $(cat /stable_plugins/stable_plugins.txt); do
        approved_plugins_url="${STABLE_PLUGIN_BASE_URL}/project/geoserver/GeoServer/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-${plugin}.zip"
        download_extension "${approved_plugins_url}" "${plugin}" /stable_plugins
      done
      for ext in $(echo "${STABLE_EXTENSIONS}" | tr ',' ' '); do
        echo "Enabling ${ext} for GeoServer ${GS_VERSION}"
        install_plugin /stable_plugins/ "${ext}"
    done
  else
    for ext in $(echo "${STABLE_EXTENSIONS}" | tr ',' ' '); do
        echo "Enabling ${ext} for GeoServer ${GS_VERSION}"
        if [[ ! -f /stable_plugins/${ext}.zip ]]; then
          approved_plugins_url="https://liquidtelecom.dl.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-${ext}.zip"
          download_extension "${approved_plugins_url}" "${ext}" /stable_plugins/
          install_plugin /stable_plugins/ "${ext}"
        else
          install_plugin /stable_plugins/ "${ext}"
        fi

    done
  fi
fi

# Function to install community extensions
function community_config() {
     echo -e "\e[32m  Installing ${ext} \033[0m"
    install_plugin /community_plugins "${ext}"
}

# Install community modules plugins
if [[ -z ${COMMUNITY_EXTENSIONS} ]]; then
  echo -e "\e[32m COMMUNITY_EXTENSIONS is unset, so we do not install any community extensions \033[0m"
else
  if  [[ ${FORCE_DOWNLOAD_COMMUNITY_EXTENSIONS} =~ [Tt][Rr][Uu][Ee] ]];then
    rm -rf /community_plugins/*.zip
    for plugin in $(cat /community_plugins/community_plugins.txt); do
      community_plugins_url="https://build.geoserver.org/geoserver/${GS_VERSION:0:5}x/community-latest/geoserver-${GS_VERSION:0:4}-SNAPSHOT-${plugin}.zip"
      download_extension "${community_plugins_url}" "${plugin}" /community_plugins
    done
    for ext in $(echo "${COMMUNITY_EXTENSIONS}" | tr ',' ' '); do
        echo "Enabling ${ext} for GeoServer ${GS_VERSION}"
        community_config
    done
  else
    for ext in $(echo "${COMMUNITY_EXTENSIONS}" | tr ',' ' '); do
        echo "Enabling ${ext} for GeoServer ${GS_VERSION}"
        if [[ ! -f /community_plugins/${ext}.zip ]]; then
          community_plugins_url="https://build.geoserver.org/geoserver/${GS_VERSION:0:5}x/community-latest/geoserver-${GS_VERSION:0:4}-SNAPSHOT-${ext}.zip"
          download_extension "${community_plugins_url}" "${ext}" /community_plugins
          community_config
        else
          community_config
        fi
    done
  fi
fi


set_vars
export MONITOR_AUDIT_PATH  INSTANCE_STRING
create_dir "${MONITOR_AUDIT_PATH}"

export REQUEST_TIMEOUT PARALLEL_REQUEST GETMAP REQUEST_EXCEL SINGLE_USER GWC_REQUEST WPS_REQUEST
# Setup control flow properties
setup_control_flow

if [[ "${TOMCAT_EXTRAS}" =~ [Tt][Rr][Uu][Ee] ]]; then
    unzip -o -qq /tomcat_apps.zip -d /tmp/ &&
    cp -r  /tmp/tomcat_apps/webapps.dist/* "${CATALINA_HOME}"/webapps/ &&
    rm -r /tmp/tomcat_apps
    if [[ -z ${TOMCAT_PASSWORD} ]]; then
        generate_random_string 18
        export TOMCAT_PASSWORD=${RAND}
        echo -e "[Entrypoint] GENERATED tomcat  PASSWORD: \e[1;31m $TOMCAT_PASSWORD \033[0m"
    else
       export TOMCAT_PASSWORD
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
        mkdir "${CATALINA_HOME}"/webapps/ROOT
        cp /build_data/index.jsp "${CATALINA_HOME}"/webapps/ROOT/index.jsp
    fi
fi


if [[ -z "${EXISTING_DATA_DIR}" ]]; then
  /scripts/update_passwords.sh
fi

setup_logging

