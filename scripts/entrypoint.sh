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

# GeoNode data dir
unzip ${REQUIRED_PLUGINS_DIR}/geonode-geoserver-ext-web-app-data.zip -d /tmp/geonode_data
rm -rf "${CATALINA_HOME}"/security
mv /tmp/geonode_data/data/security "${CATALINA_HOME}"/
cp -r -v /tmp/geonode_data/data/geofence "${GEOSERVER_DATA_DIR}"/
# End copy settings

# GeoNode
source /root/.bashrc


INVOKE_LOG_STDOUT=${INVOKE_LOG_STDOUT:-TRUE}
invoke () {
    if [ $INVOKE_LOG_STDOUT = 'true' ] || [ $INVOKE_LOG_STDOUT = 'True' ]
    then
        /usr/local/bin/invoke $@
    else
        /usr/local/bin/invoke $@ > /usr/src/geonode/invoke.log 2>&1
    fi
    echo "$@ tasks done"
}

# control the values of LB settings if present
if [ -n "$GEONODE_LB_HOST_IP" ];
then
    echo "GEONODE_LB_HOST_IP is defined and not empty with the value '$GEONODE_LB_HOST_IP' "
    echo export GEONODE_LB_HOST_IP=${GEONODE_LB_HOST_IP} >> /root/.override_env
else
    echo "GEONODE_LB_HOST_IP is either not defined or empty setting the value to 'django' "
    echo export GEONODE_LB_HOST_IP=django >> /root/.override_env
    export GEONODE_LB_HOST_IP=django
fi

if [ -n "$GEONODE_LB_PORT" ];
then
    echo "GEONODE_LB_HOST_IP is defined and not empty with the value '$GEONODE_LB_PORT' "
    echo export GEONODE_LB_PORT=${GEONODE_LB_PORT} >> /root/.override_env
else
    echo "GEONODE_LB_PORT is either not defined or empty setting the value to '8000' "
    echo export GEONODE_LB_PORT=8000 >> /root/.override_env
    export GEONODE_LB_PORT=8000
fi

if [ -n "$GEOSERVER_LB_HOST_IP" ];
then
    echo "GEOSERVER_LB_HOST_IP is defined and not empty with the value '$GEOSERVER_LB_HOST_IP' "
    echo export GEOSERVER_LB_HOST_IP=${GEOSERVER_LB_HOST_IP} >> /root/.override_env
else
    echo "GEOSERVER_LB_HOST_IP is either not defined or empty setting the value to 'geoserver' "
    echo export GEOSERVER_LB_HOST_IP=geoserver >> /root/.override_env
    export GEOSERVER_LB_HOST_IP=geoserver
fi

if [ -n "$GEOSERVER_LB_PORT" ];
then
    echo "GEOSERVER_LB_PORT is defined and not empty with the value '$GEOSERVER_LB_PORT' "
    echo export GEOSERVER_LB_PORT=${GEOSERVER_LB_PORT} >> /root/.override_env
else
    echo "GEOSERVER_LB_PORT is either not defined or empty setting the value to '8000' "
    echo export GEOSERVER_LB_PORT=8080 >> /root/.override_env
    export GEOSERVER_LB_PORT=8080
fi

# If DATABASE_HOST is not set in the environment, use the default value
if [ -n "$DATABASE_HOST" ];
then
    echo "DATABASE_HOST is defined and not empty with the value '$DATABASE_HOST' "
    echo export DATABASE_HOST=${DATABASE_HOST} >> /root/.override_env
else
    echo "DATABASE_HOST is either not defined or empty setting the value to 'db' "
    echo export DATABASE_HOST=db >> /root/.override_env
    export DATABASE_HOST=db
fi

# If DATABASE_PORT is not set in the environment, use the default value
if [ -n "$DATABASE_PORT" ];
then
    echo "DATABASE_PORT is defined and not empty with the value '$DATABASE_PORT' "
    echo export DATABASE_HOST=${DATABASE_PORT} >> /root/.override_env
else
    echo "DATABASE_PORT is either not defined or empty setting the value to '5432' "
    echo export DATABASE_PORT=5432 >> /root/.override_env
    export DATABASE_PORT=5432
fi

# If GEONODE_GEODATABASE_USER is not set in the environment, use the default value
if [ -n "$GEONODE_GEODATABASE" ];
then
    echo "GEONODE_GEODATABASE is defined and not empty with the value '$GEONODE_GEODATABASE' "
    echo export GEONODE_GEODATABASE=${GEONODE_GEODATABASE} >> /root/.override_env
else
    echo "GEONODE_GEODATABASE is either not defined or empty setting the value '${COMPOSE_PROJECT_NAME}_data' "
    echo export GEONODE_GEODATABASE=${COMPOSE_PROJECT_NAME}_data >> /root/.override_env
    export GEONODE_GEODATABASE=${COMPOSE_PROJECT_NAME}_data
fi

# If GEONODE_GEODATABASE_USER is not set in the environment, use the default value
if [ -n "$GEONODE_GEODATABASE_USER" ];
then
    echo "GEONODE_GEODATABASE_USER is defined and not empty with the value '$GEONODE_GEODATABASE_USER' "
    echo export GEONODE_GEODATABASE_USER=${GEONODE_GEODATABASE_USER} >> /root/.override_env
else
    echo "GEONODE_GEODATABASE_USER is either not defined or empty setting the value '$GEONODE_GEODATABASE' "
    echo export GEONODE_GEODATABASE_USER=${GEONODE_GEODATABASE} >> /root/.override_env
    export GEONODE_GEODATABASE_USER=${GEONODE_GEODATABASE}
fi

# If GEONODE_GEODATABASE_USER is not set in the environment, use the default value
if [ -n "$GEONODE_GEODATABASE_PASSWORD" ];
then
    echo "GEONODE_GEODATABASE_PASSWORD is defined and not empty with the value '$GEONODE_GEODATABASE_PASSWORD' "
    echo export GEONODE_GEODATABASE_PASSWORD=${GEONODE_GEODATABASE_PASSWORD} >> /root/.override_env
else
    echo "GEONODE_GEODATABASE_PASSWORD is either not defined or empty setting the value '${GEONODE_GEODATABASE}' "
    echo export GEONODE_GEODATABASE_PASSWORD=${GEONODE_GEODATABASE} >> /root/.override_env
    export GEONODE_GEODATABASE_PASSWORD=${GEONODE_GEODATABASE}
fi

# If GEONODE_GEODATABASE_SCHEMA is not set in the environment, use the default value
if [ -n "$GEONODE_GEODATABASE_SCHEMA" ];
then
    echo "GEONODE_GEODATABASE_SCHEMA is defined and not empty with the value '$GEONODE_GEODATABASE_SCHEMA' "
    echo export GEONODE_GEODATABASE_SCHEMA=${GEONODE_GEODATABASE_SCHEMA} >> /root/.override_env
else
    echo "GEONODE_GEODATABASE_SCHEMA is either not defined or empty setting the value to 'public'"
    echo export GEONODE_GEODATABASE_SCHEMA=public >> /root/.override_env
    export GEONODE_GEODATABASE_SCHEMA=public
fi


# control the value of NGINX_BASE_URL variable
if [ -z `echo ${NGINX_BASE_URL} | sed 's/http:\/\/\([^:]*\).*/\1/'` ]
then
    echo "NGINX_BASE_URL is empty so I'll use the default Geoserver base url"
    echo "Setting GEOSERVER_LOCATION='${SITEURL}'"
    echo export GEOSERVER_LOCATION=${SITEURL} >> /root/.override_env
else
    echo "NGINX_BASE_URL is filled so GEOSERVER_LOCATION='${NGINX_BASE_URL}'"
    echo "Setting GEOSERVER_LOCATION='${NGINX_BASE_URL}'"
    echo export GEOSERVER_LOCATION=${NGINX_BASE_URL} >> /root/.override_env
fi

if [ -n "$SUBSTITUTION_URL" ];
then
    echo "SUBSTITUTION_URL is defined and not empty with the value '$SUBSTITUTION_URL'"
    echo "Setting GEONODE_LOCATION='${SUBSTITUTION_URL}' "
    echo export GEONODE_LOCATION=${SUBSTITUTION_URL} >> /root/.override_env
else
    echo "SUBSTITUTION_URL is either not defined or empty so I'll use the default GeoNode location "
    echo "Setting GEONODE_LOCATION='http://${GEONODE_LB_HOST_IP}:${GEONODE_LB_PORT}' "
    echo export GEONODE_LOCATION=http://${GEONODE_LB_HOST_IP}:${GEONODE_LB_PORT} >> /root/.override_env
fi

# set basic tagname
TAGNAME=( "baseUrl" "authApiKey" )

if ! [ -f ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/config.xml ]
then
    echo "Configuration file '$GEOSERVER_DATA_DIR'/security/auth/geonodeAuthProvider/config.xml is not available so it is gone to skip "
else
    # backup geonodeAuthProvider config.xml
    cp ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/config.xml ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/config.xml.orig
    # run the setting script for geonodeAuthProvider
    /usr/local/tomcat/tmp/set_geoserver_auth.sh ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/config.xml ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/ ${TAGNAME[@]} > /dev/null 2>&1
fi

# backup geonode REST role service config.xml
cp "${GEOSERVER_DATA_DIR}/security/role/geonode REST role service/config.xml" "${GEOSERVER_DATA_DIR}/security/role/geonode REST role service/config.xml.orig"
# run the setting script for geonode REST role service
/usr/local/tomcat/tmp/set_geoserver_auth.sh "${GEOSERVER_DATA_DIR}/security/role/geonode REST role service/config.xml" "${GEOSERVER_DATA_DIR}/security/role/geonode REST role service/" ${TAGNAME[@]} > /dev/null 2>&1

# set oauth2 filter tagname
TAGNAME=( "cliendId" "clientSecret" "accessTokenUri" "userAuthorizationUri" "redirectUri" "checkTokenEndpointUrl" "logoutUri" )

# backup geonode-oauth2 config.xml
cp ${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml ${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml.orig
# run the setting script for geonode-oauth2
/usr/local/tomcat/tmp/set_geoserver_auth.sh ${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml ${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/ "${TAGNAME[@]}" > /dev/null 2>&1

# set global tagname
TAGNAME=( "proxyBaseUrl" )

# backup global.xml
cp ${GEOSERVER_DATA_DIR}/global.xml ${GEOSERVER_DATA_DIR}/global.xml.orig
# run the setting script for global configuration
/usr/local/tomcat/tmp/set_geoserver_auth.sh ${GEOSERVER_DATA_DIR}/global.xml ${GEOSERVER_DATA_DIR}/ ${TAGNAME[@]} > /dev/null 2>&1

# set correct amqp broker url
sed -i -e 's/localhost/rabbitmq/g' ${GEOSERVER_DATA_DIR}/notifier/notifier.xml

# exclude wrong dependencies
sed -i -e 's/xom-\*\.jar/xom-\*\.jar,bcprov\*\.jar/g' /usr/local/tomcat/conf/catalina.properties

# J2 templating for this docker image we should also do it for other configuration files in /usr/local/tomcat/tmp

declare -a geoserver_datadir_template_dirs=("geofence")

for template in in ${geoserver_datadir_template_dirs[*]}; do
    #Geofence templates
    if [ "$template" == "geofence" ]; then
      cp -R /templates/$template/* ${GEOSERVER_DATA_DIR}/geofence

      for f in $(find ${GEOSERVER_DATA_DIR}/geofence/ -type f -name "*.j2"); do
          echo -e "Evaluating template\n\tSource: $f\n\tDest: ${f%.j2}"
          /usr/local/bin/j2 $f > ${f%.j2}
          rm -f $f
      done

    fi
done



if [ "${FORCE_REINIT}" = "true" ]  || [ "${FORCE_REINIT}" = "True" ] || [ ! -e "${GEOSERVER_DATA_DIR}/geoserver_init.lock" ]; then
    # Run async configuration, it needs Geoserver to be up and running
    nohup sh -c "invoke configure-geoserver" &
fi

/bin/bash /scripts/start.sh



log CLUSTER_CONFIG_DIR="${CLUSTER_CONFIG_DIR}"
log MONITOR_AUDIT_PATH="${MONITOR_AUDIT_PATH}"

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
       -DUPDATE_BUILT_IN_LOGGING_PROFILES=${UPDATE_LOGGING_PROFILES} \
       -DRELINQUISH_LOG4J_CONTROL=${RELINQUISH_LOG4J_CONTROL} \
       -DGEOSERVER_CONSOLE_DISABLED=${DISABLE_WEB_INTERFACE} \
       -DGWC_DISKQUOTA_DISABLED=${DISKQUOTA_DISABLED} \
       -DGEOSERVER_CSRF_WHITELIST=${CSRF_WHITELIST} \
       -Dgeoserver.xframe.shouldSetPolicy=${XFRAME_OPTIONS} \
       -DGEOSERVER_REQUIRE_FILE=${GEOSERVER_REQUIRE_FILE} \
       -DENTITY_RESOLUTION_ALLOWLIST='"${ENTITY_RESOLUTION_ALLOWLIST}"' \
       -DGEOSERVER_DISABLE_STATIC_WEB_FILES=${GEOSERVER_DISABLE_STATIC_WEB_FILES} \
       -DPRINT_BASE_URL=${PRINT_BASE_URL} \
       ${ADDITIONAL_JAVA_STARTUP_OPTIONS} "

## Prepare the JVM command line arguments
export JAVA_OPTS="${JAVA_OPTS} ${GEOSERVER_OPTS}"


# Chown again - seems to fix issue with resolving all created directories
if [[ ${RUN_AS_ROOT} =~ [Ff][Aa][Ll][Ss][Ee] ]];then
  dir_ownership=("${CATALINA_HOME}" /home/"${USER_NAME}"/ "${COMMUNITY_PLUGINS_DIR}"
    "${STABLE_PLUGINS_DIR}" "${REQUIRED_PLUGINS_DIR}" "${GEOSERVER_HOME}" /usr/share/fonts/ /tomcat_apps.zip
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