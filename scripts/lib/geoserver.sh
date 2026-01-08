#!/usr/bin/env bash

############################################
# Helper functions containing
# setup_custom_crs
# setup_custom_override_crs
# unzip_geoserver
# package_geoserver
# install_plugin
# default_disk_quota_config
# jdbc_disk_quota_config
# activate_gwc_global_configs
# setup_control_flow
# s3_config
############################################

# Function to add custom crs in geoserver data directory
# https://docs.geoserver.org/latest/en/user/configuration/crshandling/customcrs.html
setup_custom_crs() {
  if [[ -f "${EXTRA_CONFIG_DIR}/epsg.properties" ]]; then
    cp -f "${EXTRA_CONFIG_DIR}/epsg.properties" \
          "${GEOSERVER_DATA_DIR}/user_projections/"
  elif [[ ! -f "${GEOSERVER_DATA_DIR}/user_projections/epsg.properties" ]]; then
    cp -r "${CATALINA_HOME}/data/user_projections/epsg.properties" \
          "${GEOSERVER_DATA_DIR}/user_projections/epsg.properties"
  fi
}

setup_custom_override_crs() {
  [[ -f "${EXTRA_CONFIG_DIR}/epsg_overrides.properties" ]] &&
    cp -f "${EXTRA_CONFIG_DIR}/epsg_overrides.properties" \
          "${GEOSERVER_DATA_DIR}/user_projections/"
}

unzip_geoserver() {
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
package_geoserver() {
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

# Helper function to install plugin in proper path

install_plugin() {
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

default_disk_quota_config() {
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

jdbc_disk_quota_config() {

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

activate_gwc_global_configs() {
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
setup_control_flow() {
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



