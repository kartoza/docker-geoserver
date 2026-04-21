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
# GEOSERVER PACKAGING & INSTALL
############################################
detect_install_dir() {
  [[ -f "${GEOSERVER_HOME}/start.jar" ]] && echo "${GEOSERVER_HOME}" || echo "${CATALINA_HOME}"
}

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



install_plugin_libjpegturbo() {
  local arch deb version
  arch=$(dpkg --print-architecture)
  version="2.1.5.1"
  deb="libjpeg-turbo-official_${version}_${arch}.deb"
  dpkg -i "${REQUIRED_PLUGINS_DIR}/${deb}"
}

############################################
# GWC, CONTROL FLOW, MONITORING
############################################

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

############################################
# GDAL VERSION SYNC
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
# STATUS WRAPPERS (ENTRYPOINT CALLS)
############################################

setup_control_flow_status() {
  export REQUEST_TIMEOUT PARALLEL_REQUEST GETMAP REQUEST_EXCEL SINGLE_USER GWC_REQUEST WPS_REQUEST USER_WMS_REQUEST THROTTLE_REQUEST_PER_IP
  setup_control_flow
}

setup_gwc_status() {
  export WMS_DIR_INTEGRATION REQUIRE_TILED_PARAMETER WMSC_ENABLED TMS_ENABLED SECURITY_ENABLED
  activate_gwc_global_configs
}

setup_crs_status() {
  create_dir "${GEOWEBCACHE_CACHE_DIR}"
  create_dir "${GEOSERVER_DATA_DIR}/user_projections"
  setup_custom_crs
  setup_custom_override_crs
}

setup_disk_quota_status() {
  export DISK_QUOTA_FREQUENCY DISK_QUOTA_SIZE
  setup_disk_quota
}
