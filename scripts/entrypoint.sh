#!/bin/bash
set -e


figlet -t "Kartoza Docker GeoServer"

# Gosu preparations
USER_ID=${GEOSERVER_UID:-1000}
GROUP_ID=${GEOSERVER_GID:-1000}
USER_NAME=${USER:-geoserveruser}
GEO_GROUP_NAME=${GROUP_NAME:-geoserverusers}

# Add group
if [ ! $(getent group "${GEO_GROUP_NAME}") ]; then
  groupadd -r "${GEO_GROUP_NAME}" -g ${GROUP_ID}
fi

# Add user to system
if id "${USER_NAME}" &>/dev/null; then
    echo ' skipping user creation'
else
    useradd -l -m -d /home/"${USER_NAME}"/ -u "${USER_ID}" --gid "${GROUP_ID}" -s /bin/bash -G "${GEO_GROUP_NAME}" "${USER_NAME}"
fi

# Create directories
mkdir -p  "${GEOSERVER_DATA_DIR}" "${CERT_DIR}" "${FOOTPRINTS_DATA_DIR}" "${FONTS_DIR}" "${GEOWEBCACHE_CACHE_DIR}" \
"${GEOSERVER_HOME}" "${EXTRA_CONFIG_DIR}"



source /scripts/functions.sh
source /scripts/env-data.sh

# Credits https://github.com/kartoza/docker-geoserver/pull/371
set_vars
export  READONLY CLUSTER_DURABILITY BROKER_URL EMBEDDED_BROKER TOGGLE_MASTER TOGGLE_SLAVE BROKER_URL
export CLUSTER_CONFIG_DIR MONITOR_AUDIT_PATH CLUSTER_LOCKFILE INSTANCE_STRING

/bin/bash /scripts/start.sh



log CLUSTER_CONFIG_DIR="${CLUSTER_CONFIG_DIR}"
log MONITOR_AUDIT_PATH="${MONITOR_AUDIT_PATH}"

export GEOSERVER_OPTS="-Djava.awt.headless=true -server -Xms${INITIAL_MEMORY} -Xmx${MAXIMUM_MEMORY} \
       -XX:PerfDataSamplingInterval=500 -Dorg.geotools.referencing.forceXY=true \
       -XX:SoftRefLRUPolicyMSPerMB=36000  -XX:NewRatio=2 \
       -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=20 -XX:ConcGCThreads=5 \
       -XX:InitiatingHeapOccupancyPercent=${INITIAL_HEAP_OCCUPANCY_PERCENT} -XX:+CMSClassUnloadingEnabled \
       -Djts.overlay=ng \
       -Dfile.encoding=${ENCODING} \
       -Duser.timezone=${TIMEZONE} \
       -Duser.language=${LANGUAGE} \
       -Duser.region=${REGION} \
       -Duser.country=${COUNTRY} \
       -DENABLE_JSONP=${ENABLE_JSONP} \
       -DMAX_FILTER_RULES=${MAX_FILTER_RULES} \
       -DOPTIMIZE_LINE_WIDTH=${OPTIMIZE_LINE_WIDTH} \
       -DALLOW_ENV_PARAMETRIZATION=${PROXY_BASE_URL_PARAMETRIZATION} \
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
       --patch-module java.desktop=${CATALINA_HOME}/marlin-render.jar  \
       -Dsun.java2d.renderer=org.marlin.pisces.PiscesRenderingEngine \
       -Dgeoserver.login.autocomplete=${LOGIN_STATUS} \
       -DGEOSERVER_CONSOLE_DISABLED=${DISABLE_WEB_INTERFACE} \
       -DGEOSERVER_CSRF_WHITELIST=${CSRF_WHITELIST} \
       -Dgeoserver.xframe.shouldSetPolicy=${XFRAME_OPTIONS} \
       ${ADDITIONAL_JAVA_STARTUP_OPTIONS} "

## Prepare the JVM command line arguments
export JAVA_OPTS="${JAVA_OPTS} ${GEOSERVER_OPTS}"


# Chown again - seems to fix issue with resolving all created directories
chown -R "${USER_NAME}":"${GEO_GROUP_NAME}" "${CATALINA_HOME}" "${FOOTPRINTS_DATA_DIR}" "${GEOSERVER_DATA_DIR}" \
"${CERT_DIR}" "${FONTS_DIR}"  /home/"${USER_NAME}"/ "${COMMUNITY_PLUGINS_DIR}" "${STABLE_PLUGINS_DIR}" \
"${GEOSERVER_HOME}" "${EXTRA_CONFIG_DIR}"  /usr/share/fonts/ /scripts /tomcat_apps.zip \
/tmp/ "${GEOWEBCACHE_CACHE_DIR}";chmod o+rw "${CERT_DIR}";chmod 400 ${CATALINA_HOME}/conf/*

if [[ -f ${GEOSERVER_HOME}/start.jar ]]; then
  exec gosu ${USER_NAME} ${GEOSERVER_HOME}/bin/startup.sh
else
  exec gosu ${USER_NAME} /usr/local/tomcat/bin/catalina.sh run
fi