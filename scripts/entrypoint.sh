#!/bin/bash
set -e


figlet -t "Kartoza Docker GeoServer"

# Gosu preparations
USER_ID=${GEOSERVER_UID:-1000}
GROUP_ID=${GEOSERVER_GID:-1000}
USER_NAME=${USER:-geoserveruser}
GEO_GROUP_NAME=${GROUP_NAME:-geoserverusers}

# Add group
if [ ! "$(getent group "${GEO_GROUP_NAME}")" ]; then
  groupadd -r "${GEO_GROUP_NAME}" -g "${GROUP_ID}"
fi

# Add user to system
if ! id -u "${USER_NAME}" >/dev/null 2>&1; then
    useradd -l -m -d /home/"${USER_NAME}"/ -u "${USER_ID}" --gid "${GROUP_ID}" -s /bin/bash -G "${GEO_GROUP_NAME}" "${USER_NAME}"
fi

# Import env and functions
source /scripts/functions.sh
source /scripts/env-data.sh

# Create directories
dir_creation=("${GEOSERVER_DATA_DIR}" "${CERT_DIR}" "${FOOTPRINTS_DATA_DIR}" "${FONTS_DIR}" "${GEOWEBCACHE_CACHE_DIR}"
"${GEOSERVER_HOME}" "${EXTRA_CONFIG_DIR}" "/docker-entrypoint-geoserver.d")
for directory in "${dir_creation[@]}"; do
  create_dir "${directory}"
done

# Rename to match wanted context-root and so that we can unzip plugins to
# existing directory.
if [ x"${GEOSERVER_CONTEXT_ROOT}" != xgeoserver ]; then
  echo "INFO: changing context-root to '${GEOSERVER_CONTEXT_ROOT}'."
  GEOSERVER_INSTALL_DIR="$(detect_install_dir)"
  if [ -e "${GEOSERVER_INSTALL_DIR}/webapps/geoserver" ]; then
    mkdir -p "$(dirname -- "${GEOSERVER_INSTALL_DIR}/webapps/${GEOSERVER_CONTEXT_ROOT}")"
    mv "${GEOSERVER_INSTALL_DIR}/webapps/geoserver" "${GEOSERVER_INSTALL_DIR}/webapps/${GEOSERVER_CONTEXT_ROOT}"
  else
    echo "WARN: '${GEOSERVER_INSTALL_DIR}/webapps/geoserver' not found, probably already renamed as this is probably a container restart and not first run."
  fi
fi

# Credits https://github.com/kartoza/docker-geoserver/pull/371
set_vars
export  READONLY CLUSTER_DURABILITY BROKER_URL EMBEDDED_BROKER TOGGLE_MASTER TOGGLE_SLAVE BROKER_URL
export CLUSTER_CONFIG_DIR MONITOR_AUDIT_PATH INSTANCE_STRING  CLUSTER_CONNECTION_RETRY_COUNT CLUSTER_CONNECTION_MAX_WAIT


/bin/bash /scripts/start.sh



log CLUSTER_CONFIG_DIR="${CLUSTER_CONFIG_DIR}"
log MONITOR_AUDIT_PATH="${MONITOR_AUDIT_PATH}"
if [[ -z ${GEOSERVER_OPTS} ]];then

export GEOSERVER_OPTS="-Djava.awt.headless=true -server -Xms${INITIAL_MEMORY} -Xmx${MAXIMUM_MEMORY} \
       -XX:PerfDataSamplingInterval=500 -Dorg.geotools.referencing.forceXY=true \
       -XX:SoftRefLRUPolicyMSPerMB=36000   \
       -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=20 -XX:ConcGCThreads=5 \
       -XX:InitiatingHeapOccupancyPercent=${INITIAL_HEAP_OCCUPANCY_PERCENT}  \
       -Djts.overlay=ng \
       -Dfile.encoding=${ENCODING} \
       -Duser.timezone=${TIMEZONE} \
       -Duser.language=${LANGUAGE} \
       -Duser.region=${REGION} \
       -Duser.country=${COUNTRY} \
       -DENABLE_JSONP=${ENABLE_JSONP} \
       -DMAX_FILTER_RULES=${MAX_FILTER_RULES} \
       -DOPTIMIZE_LINE_WIDTH=${OPTIMIZE_LINE_WIDTH} \
       -DALLOW_ENV_PARAMETRIZATION=${ALLOW_ENV_PARAMETRIZATION} \
       -Djavax.servlet.request.encoding=${CHARACTER_ENCODING} \
       -Djavax.servlet.response.encoding=${CHARACTER_ENCODING} \
       -DCLUSTER_CONFIG_DIR=${CLUSTER_CONFIG_DIR} \
       -DGEOSERVER_DATA_DIR=${GEOSERVER_DATA_DIR} \
       -DGEOSERVER_FILEBROWSER_HIDEFS=${GEOSERVER_FILEBROWSER_HIDEFS} \
       -DGEOSERVER_AUDIT_PATH=${MONITOR_AUDIT_PATH} \
       -Dorg.geotools.shapefile.datetime=${USE_DATETIME_IN_SHAPEFILE} \
       -Dorg.geotools.localDateTimeHandling=true \
       -Dsun.java2d.renderer.useThreadLocal=false \
       -Dsun.java2d.renderer.pixelsize=8192 -server -XX:NewSize=300m \
       -Dlog4j.configuration=${CATALINA_HOME}/log4j.properties \
       --patch-module java.desktop=${CATALINA_HOME}/lib/marlin.jar \
       -Dsun.java2d.renderer=org.marlin.pisces.PiscesRenderingEngine \
       -Dsun.java2d.renderer.log=true \
       -Dgeoserver.login.autocomplete=${LOGIN_STATUS} \
       -DUPDATE_BUILT_IN_LOGGING_PROFILES=${UPDATE_LOGGING_PROFILES} \
       -DRELINQUISH_LOG4J_CONTROL=${RELINQUISH_LOG4J_CONTROL} \
       -DGEOSERVER_CONSOLE_DISABLED=${DISABLE_WEB_INTERFACE} \
       -DGWC_DISKQUOTA_DISABLED=${DISKQUOTA_DISABLED} \
       -DGEOSERVER_CSRF_WHITELIST=${CSRF_WHITELIST} \
       -Dgeoserver.xframe.shouldSetPolicy=${XFRAME_OPTIONS} \
       -DGEOSERVER_REQUIRE_FILE=${GEOSERVER_REQUIRE_FILE} \
       -DENTITY_RESOLUTION_ALLOWLIST='"${ENTITY_RESOLUTION_ALLOWLIST}"' \
       -DGEOSERVER_DISABLE_STATIC_WEB_FILES=${GEOSERVER_DISABLE_STATIC_WEB_FILES} \
       ${ADDITIONAL_JAVA_STARTUP_OPTIONS} "
fi
## Prepare the JVM command line arguments
export JAVA_OPTS="${JAVA_OPTS} ${GEOSERVER_OPTS}"


# Chown again - seems to fix issue with resolving all created directories
if [[ ${RUN_AS_ROOT} =~ [Ff][Aa][Ll][Ss][Ee] ]];then
  dir_ownership=("${CATALINA_HOME}" /home/"${USER_NAME}"/ "${COMMUNITY_PLUGINS_DIR}"
    "${STABLE_PLUGINS_DIR}" "${REQUIRED_PLUGINS_DIR}" "${GEOSERVER_HOME}" /usr/share/fonts/
    /tmp/ "${FOOTPRINTS_DATA_DIR}" "${CERT_DIR}" "${FONTS_DIR}" /scripts/
    "${EXTRA_CONFIG_DIR}" "/docker-entrypoint-geoserver.d" "${MONITOR_AUDIT_PATH}")
  for directory in "${dir_ownership[@]}"; do
    if [[ $(stat -c '%U' "${directory}") != "${USER_NAME}" ]] && [[ $(stat -c '%G' "${directory}") != "${GEO_GROUP_NAME}" ]];then
      chown -R "${USER_NAME}":"${GEO_GROUP_NAME}" "${directory}"
    fi
  done
  if [[ -d "${CLUSTER_CONFIG_DIR}" ]];then
    chown -R "${USER_NAME}":"${GEO_GROUP_NAME}" "${CLUSTER_CONFIG_DIR}"
  fi
  chown -R "${USER_NAME}":"${GEO_GROUP_NAME}" "${GEOSERVER_DATA_DIR}"/logging.xml
  if [[ -d "${GEOSERVER_DATA_DIR}"/jdbcconfig ]];then
    chown -R "${USER_NAME}":"${GEO_GROUP_NAME}" "${GEOSERVER_DATA_DIR}"/jdbcconfig
  fi

  if [[ -d "${GEOSERVER_DATA_DIR}"/jdbcstore ]];then
    chown -R "${USER_NAME}":"${GEO_GROUP_NAME}" "${GEOSERVER_DATA_DIR}"/jdbcstore
  fi
  if [[ -d "${GEOSERVER_LOG_DIR}" ]];then
    chown -R "${USER_NAME}":"${GEO_GROUP_NAME}" "${GEOSERVER_LOG_DIR}"
  fi
  # hazel cluster
  if [[ -d "${GEOSERVER_DATA_DIR}"/cluster ]];then
    chown -R "${USER_NAME}":"${GEO_GROUP_NAME}" "${GEOSERVER_DATA_DIR}"/cluster
  fi
fi



chmod o+rw "${CERT_DIR}";gwc_file_perms ;chmod 400 "${CATALINA_HOME}"/conf/*

if [[ ${SAMPLE_DATA} =~ [Tt][Rr][Uu][Ee] ]]; then
  chown -R "${USER_NAME}":"${GEO_GROUP_NAME}" "${GEOSERVER_DATA_DIR}"
fi

if [[ ${RUN_AS_ROOT} =~ [Ff][Aa][Ll][Ss][Ee] ]];then
  if [[ -f ${GEOSERVER_HOME}/start.jar ]]; then
    exec gosu "${USER_NAME}" "${GEOSERVER_HOME}"/bin/startup.sh
  else
    exec gosu "${USER_NAME}" /usr/local/tomcat/bin/catalina.sh run
  fi
else
  if [[ -f ${GEOSERVER_HOME}/start.jar ]]; then
    exec  "${GEOSERVER_HOME}"/bin/startup.sh
  else
    exec  /usr/local/tomcat/bin/catalina.sh run
  fi
fi
