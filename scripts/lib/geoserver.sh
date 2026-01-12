#!/usr/bin/env bash

############################################
# GEOSERVER INSTALL & EXTENSION HELPERS
############################################


############################################
# 1. CRS CONFIGURATION
############################################
# https://docs.geoserver.org/latest/en/user/configuration/crshandling/customcrs.html
############################################

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

############################################
# 2. DISK QUOTA (GWC)
############################################

reset_disk_quota() {
  [[ "${RECREATE_DISKQUOTA}" =~ [Tt][Rr][Uu][Ee] ]] || return

  rm -f \
    "${GEOWEBCACHE_CACHE_DIR}/geowebcache-diskquota.xml" \
    "${GEOWEBCACHE_CACHE_DIR}/geowebcache-diskquota-jdbc.xml"
}

default_disk_quota_config() {
  [[ -f "${GEOWEBCACHE_CACHE_DIR}/geowebcache-diskquota.xml" ]] && return

  if [[ -f "${EXTRA_CONFIG_DIR}/geowebcache-diskquota.xml" ]]; then
    envsubst < "${EXTRA_CONFIG_DIR}/geowebcache-diskquota.xml" \
      > "${GEOWEBCACHE_CACHE_DIR}/geowebcache-diskquota.xml"
  else
    envsubst < /build_data/geowebcache-diskquota.xml \
      > "${GEOWEBCACHE_CACHE_DIR}/geowebcache-diskquota.xml"
  fi
}

jdbc_disk_quota_config() {
  [[ -f "${GEOWEBCACHE_CACHE_DIR}/geowebcache-diskquota-jdbc.xml" ]] && return

  if [[ -f "${EXTRA_CONFIG_DIR}/geowebcache-diskquota-jdbc.xml" ]]; then
    envsubst < "${EXTRA_CONFIG_DIR}/geowebcache-diskquota-jdbc.xml" \
      > "${GEOWEBCACHE_CACHE_DIR}/geowebcache-diskquota-jdbc.xml"
  else
    envsubst < /build_data/geowebcache-diskquota-jdbc.xml \
      > "${GEOWEBCACHE_CACHE_DIR}/geowebcache-diskquota-jdbc.xml"
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

############################################
# 3. GEOSERVER PACKAGING & INSTALL
############################################

validate_geo_install() {
  [[ -d "$1" && "$(ls -A "$1")" ]] || {
    echo "GeoServer install dir missing, exiting"
    exit 1
  }
}

unzip_geoserver() {
  if [[ -f /tmp/geoserver/geoserver.war ]]; then
    unzip /tmp/geoserver/geoserver.war \
      -d "${CATALINA_HOME}/webapps/${GEOSERVER_CONTEXT_ROOT}"

    validate_geo_install "${CATALINA_HOME}/webapps/${GEOSERVER_CONTEXT_ROOT}"

    cp -r "${CATALINA_HOME}/webapps/${GEOSERVER_CONTEXT_ROOT}/data" "${CATALINA_HOME}"
    mv "${CATALINA_HOME}/data/security" "${CATALINA_HOME}"
    rm -rf "${CATALINA_HOME}/webapps/${GEOSERVER_CONTEXT_ROOT}/data"

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

install_geoserver_core() {
  pushd "${CATALINA_HOME}" || exit
  package_geoserver

  cp /build_data/stable_plugins.txt "${STABLE_PLUGINS_DIR}"
  cp /build_data/community_plugins.txt "${COMMUNITY_PLUGINS_DIR}"
  cp /build_data/letsencrypt-tomcat.xsl "${CATALINA_HOME}/conf/ssl-tomcat.xsl"
}

install_required_jars() {
  pushd "${CATALINA_HOME}" || exit

  cp "${REQUIRED_PLUGINS_DIR}/marlin.jar" "${CATALINA_HOME}/lib/marlin.jar"

  if [[ -f ${GEOSERVER_HOME}/start.jar ]]; then
    cp "${REQUIRED_PLUGINS_DIR}/jetty-servlets-11.0.9.jar" \
       "${GEOSERVER_HOME}/webapps/${GEOSERVER_CONTEXT_ROOT}/WEB-INF/lib/"
    cp "${REQUIRED_PLUGINS_DIR}/jetty-util.jar" \
       "${GEOSERVER_HOME}/webapps/${GEOSERVER_CONTEXT_ROOT}/WEB-INF/lib/"
  fi
}


############################################
# 4. PLUGIN MANAGEMENT
############################################

download_extension() {
  curl --progress-bar -fL \
    -o "$3/$2.zip" "$1"
}

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

############################################
# 5. EXTENSIONS (STABLE & COMMUNITY)
############################################

setup_stable_extensions(){
  if [[ "$ACTIVE_EXTENSIONS" != "$DEFAULT_EXTENSIONS" ]]; then

  for ext in $(echo "${ACTIVE_EXTENSIONS}" | tr ',' ' '); do
    if echo "${DEFAULT_EXTENSIONS}" | grep -w "${ext}" >/dev/null; then
      if [[ ! -f ${REQUIRED_PLUGINS_DIR}/${ext}.zip ]]; then
        approved_plugins_url="${STABLE_PLUGIN_BASE_URL}/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-${ext}.zip"
        download_extension "${approved_plugins_url}" "${ext}" ${REQUIRED_PLUGINS_DIR}/
      fi
      install_plugin ${REQUIRED_PLUGINS_DIR}/ "${ext}"
    else
      if [[ ! -f ${STABLE_PLUGINS_DIR}/${ext}.zip ]]; then
        # Download the stable extension
        approved_plugins_url="${STABLE_PLUGIN_BASE_URL}/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-${ext}.zip"
        download_extension "${approved_plugins_url}" "${ext}" ${STABLE_PLUGINS_DIR}/
      fi
      # Install the stable extension
      install_plugin ${STABLE_PLUGINS_DIR}/ "${ext}"
    fi
  done
else
  # Install default plugins
  for ext in $(echo "${DEFAULT_EXTENSIONS}" | tr ',' ' '); do
    if [[ ! -f ${REQUIRED_PLUGINS_DIR}/${ext}.zip ]]; then
        approved_plugins_url="${STABLE_PLUGIN_BASE_URL}/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-${ext}.zip"
        download_extension "${approved_plugins_url}" "${ext}" ${REQUIRED_PLUGINS_DIR}/
    fi
    install_plugin ${REQUIRED_PLUGINS_DIR}/ "${ext}"
  done
fi

}

setup_community_extensions(){
  if [[ ! -z ${COMMUNITY_EXTENSIONS} ]]; then
  if  [[ ${FORCE_DOWNLOAD_COMMUNITY_EXTENSIONS} =~ [Tt][Rr][Uu][Ee] ]];then
    rm -rf /community_plugins/*.zip
  fi

  for ext in $(echo "${COMMUNITY_EXTENSIONS}" | tr ',' ' '); do
      if [[ ! -f /community_plugins/${ext}.zip ]]; then
        community_plugins_url="https://build.geoserver.org/geoserver/${GS_VERSION:0:5}x/community-latest/geoserver-${GS_VERSION:0:4}-SNAPSHOT-${ext}.zip"
        download_extension "${community_plugins_url}" "${ext}" /community_plugins
        setup_jdbc_db_store
        setup_jdbc_db_config
        setup_hz_cluster
        install_plugin /community_plugins "${ext}"
      else
        setup_jdbc_db_store
        setup_jdbc_db_config
        setup_hz_cluster
        install_plugin /community_plugins "${ext}"
      fi
  done

fi

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
############################################
# 6. GWC, CONTROL FLOW, MONITORING
############################################

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


setup_monitoring_status() {
  create_dir "${MONITOR_AUDIT_PATH}"
  export MONITORING_AUDIT_ENABLED MONITORING_AUDIT_ROLL_LIMIT
  setup_monitoring
}

############################################
# 7. GDAL VERSION SYNC
############################################

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

############################################
# 8. STATUS WRAPPERS (ENTRYPOINT CALLS)
############################################

setup_control_flow_status() {
  export REQUEST_TIMEOUT PARALLEL_REQUEST
  setup_control_flow
}

setup_gwc_status() {
  export WMS_DIR_INTEGRATION SECURITY_ENABLED
  activate_gwc_global_configs
}

setup_community_extensions_status() {
  export JDBC_CONFIG_ENABLED JDBC_STORE_ENABLED POSTGRES_JNDI
  setup_community_extensions
}

############################################
# 9. EXTERNAL / CROSS-FILE DEPENDENCIES
############################################
#
# Defined elsewhere:
#   - create_dir
#   - detect_install_dir
#   - postgres_ssl_setup
#   - postgres_ready_status
#   - create_gwc_tile_tables
#   - setup_jdbc_db_store
#   - setup_jdbc_db_config
#   - setup_hz_cluster
#   - setup_monitoring
#
# Environment dependencies:
#   - GEOSERVER_DATA_DIR
#   - GEOWEBCACHE_CACHE_DIR
#   - EXTRA_CONFIG_DIR
#   - REQUIRED_PLUGINS_DIR
#   - STABLE_PLUGINS_DIR
#   - GS_VERSION
#   - DB_BACKEND
#
############################################