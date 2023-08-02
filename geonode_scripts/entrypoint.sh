#!/bin/bash
set -e

source /root/.bashrc

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
export MONITOR_AUDIT_PATH INSTANCE_STRING

/bin/bash /scripts/start.sh

log MONITOR_AUDIT_PATH="${MONITOR_AUDIT_PATH}"

# control the value of DOCKER_HOST_IP variable
if [ -z ${DOCKER_HOST_IP} ];then

    echo "DOCKER_HOST_IP is empty so I'll run the python utility \n"
    echo export DOCKER_HOST_IP=`python3 /usr/local/tomcat/tmp/get_dockerhost_ip.py` >> /root/.override_env
    echo "The calculated value is now DOCKER_HOST_IP='$DOCKER_HOST_IP' \n"

else

    echo "DOCKER_HOST_IP is filled so I'll leave the found value '$DOCKER_HOST_IP' \n"

fi

# control the values of LB settings if present
if [ ${GEONODE_LB_HOST_IP} ];then

    echo "GEONODE_LB_HOST_IP is filled so I replace the value of '$DOCKER_HOST_IP' with '$GEONODE_LB_HOST_IP' \n"
    echo export DOCKER_HOST_IP=${GEONODE_LB_HOST_IP} >> /root/.override_env

fi

if [ ${GEONODE_LB_PORT} ];then

    echo "GEONODE_LB_PORT is filled so I replace the value of '$PUBLIC_PORT' with '$GEONODE_LB_PORT' \n"
    echo export PUBLIC_PORT=${GEONODE_LB_PORT} >> /root/.override_env

fi

#if [ ! -z "${GEOSERVER_JAVA_OPTS}" ];then
#
#    echo "GEOSERVER_JAVA_OPTS is filled so I replace the value of '$JAVA_OPTS' with '$GEOSERVER_JAVA_OPTS' \n"
#    JAVA_OPTS=${GEOSERVER_JAVA_OPTS}
#
#fi

# control the value of NGINX_BASE_URL variable
if [ -z `echo ${NGINX_BASE_URL} | sed 's/http:\/\/\([^:]*\).*/\1/'` ];then
    echo "NGINX_BASE_URL is empty so I'll use the static nginx hostname \n"
    # echo export NGINX_BASE_URL=`python3 /usr/local/tomcat/tmp/get_nginxhost_ip.py` >> /root/.override_env
    # TODO rework get_nginxhost_ip to get URL with static hostname from nginx service name
    # + exposed port of that container i.e. http://geonode:80
    echo export NGINX_BASE_URL=http://geonode:80 >> /root/.override_env
    echo "The calculated value is now NGINX_BASE_URL='$NGINX_BASE_URL' \n"
else
    echo "NGINX_BASE_URL is filled so I'll leave the found value '$NGINX_BASE_URL' \n"
fi

# set basic tagname
TAGNAME=( "baseUrl" )

if ! [ -f ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/config.xml ];then

    echo "Configuration file '$GEOSERVER_DATA_DIR'/security/auth/geonodeAuthProvider/config.xml is not available so it is gone to skip \n"

else

    # backup geonodeAuthProvider config.xml
    cp ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/config.xml ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/config.xml.orig
    # run the setting script for geonodeAuthProvider
    /usr/local/tomcat/tmp/set_geoserver_auth.sh ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/config.xml ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/ ${TAGNAME} > /dev/null 2>&1

fi

# backup geonode REST role service config.xml
cp "${GEOSERVER_DATA_DIR}/security/role/geonode REST role service/config.xml" "${GEOSERVER_DATA_DIR}/security/role/geonode REST role service/config.xml.orig"
# run the setting script for geonode REST role service
/usr/local/tomcat/tmp/set_geoserver_auth.sh "${GEOSERVER_DATA_DIR}/security/role/geonode REST role service/config.xml" "${GEOSERVER_DATA_DIR}/security/role/geonode REST role service/" ${TAGNAME} > /dev/null 2>&1

# set oauth2 filter tagname
TAGNAME=( "accessTokenUri" "userAuthorizationUri" "redirectUri" "checkTokenEndpointUrl" "logoutUri" )

# backup geonode-oauth2 config.xml
cp ${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml ${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml.orig
# run the setting script for geonode-oauth2
/usr/local/tomcat/tmp/set_geoserver_auth.sh ${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml ${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/ "${TAGNAME[@]}" > /dev/null 2>&1

# Add custom logic to make styling work
#sed -i 's|http://geonode:80/api/o/v4/tokeninfo/|https://${GEONODE_LB_HOST_IP}/api/o/v4/tokeninfo/|' ${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml


# set global tagname
TAGNAME=( "proxyBaseUrl" )

# backup global.xml
cp ${GEOSERVER_DATA_DIR}/global.xml ${GEOSERVER_DATA_DIR}/global.xml.orig
# run the setting script for global configuration
/usr/local/tomcat/tmp/set_geoserver_auth.sh ${GEOSERVER_DATA_DIR}/global.xml ${GEOSERVER_DATA_DIR}/ ${TAGNAME} > /dev/null 2>&1

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

# configure CORS (inspired by https://github.com/oscarfonts/docker-geoserver)
# if enabled, this will add the filter definitions
# to the end of the web.xml
# (this will only happen if our filter has not yet been added before)
if [ "${GEOSERVER_CORS_ENABLED}" = "true" ] || [ "${GEOSERVER_CORS_ENABLED}" = "True" ]; then
  if ! grep -q DockerGeoServerCorsFilter "$CATALINA_HOME/webapps/geoserver/WEB-INF/web.xml"; then
    echo "Enable CORS for $CATALINA_HOME/webapps/geoserver/WEB-INF/web.xml"
    sed -i "\:</web-app>:i\\
    <filter>\n\
      <filter-name>DockerGeoServerCorsFilter</filter-name>\n\
      <filter-class>org.apache.catalina.filters.CorsFilter</filter-class>\n\
      <init-param>\n\
          <param-name>cors.allowed.origins</param-name>\n\
          <param-value>${GEOSERVER_CORS_ALLOWED_ORIGINS}</param-value>\n\
      </init-param>\n\
      <init-param>\n\
          <param-name>cors.allowed.methods</param-name>\n\
          <param-value>${GEOSERVER_CORS_ALLOWED_METHODS}</param-value>\n\
      </init-param>\n\
      <init-param>\n\
        <param-name>cors.allowed.headers</param-name>\n\
        <param-value>${GEOSERVER_CORS_ALLOWED_HEADERS}</param-value>\n\
      </init-param>\n\
    </filter>\n\
    <filter-mapping>\n\
      <filter-name>DockerGeoServerCorsFilter</filter-name>\n\
      <url-pattern>/*</url-pattern>\n\
    </filter-mapping>" "$CATALINA_HOME/webapps/geoserver/WEB-INF/web.xml";
  fi
fi


echo ${JAVA_OPTS}
# Custom startup Options
export GEOSERVER_OPTS="-Djava.awt.headless=true -server -Xms${INITIAL_MEMORY} -Xmx${MAXIMUM_MEMORY} \
       -XX:PerfDataSamplingInterval=500 \
       -Dorg.geotools.referencing.forceXY=true \
       -XX:SoftRefLRUPolicyMSPerMB=36000  \
       -XX:NewRatio=2 \
       -XX:+UseG1GC -XX:MaxGCPauseMillis=200 \
       -XX:ParallelGCThreads=20 \
       -XX:ConcGCThreads=5 \
       -XX:InitiatingHeapOccupancyPercent=${INITIAL_HEAP_OCCUPANCY_PERCENT} \
       -XX:+CMSClassUnloadingEnabled \
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
       -DGEOSERVER_DATA_DIR=${GEOSERVER_DATA_DIR} \
       -DGEOSERVER_CSRF_DISABLED=true \
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
       -Dgwc.context.suffix=gwc \
       -Dgeofence-ovr=${GEOSERVER_DATA_DIR}/geofence/geofence-datasource-ovr.properties \
       -DPRINT_BASE_URL=${PRINT_BASE_URL} \
       ${ADDITIONAL_JAVA_STARTUP_OPTIONS} "

export JAVA_OPTS="${JAVA_OPTS} ${GEOSERVER_OPTS}"


# start tomcat
#export JAVA_OPTS="${JAVA_OPTS}"
# Chown again - seems to fix issue with resolving all created directories
chown -R "${USER_NAME}":"${GEO_GROUP_NAME}" "${CATALINA_HOME}" "${FOOTPRINTS_DATA_DIR}" "${GEOSERVER_DATA_DIR}" \
"${CERT_DIR}" "${FONTS_DIR}"  /home/"${USER_NAME}"/ "${COMMUNITY_PLUGINS_DIR}" "${STABLE_PLUGINS_DIR}" \
"${GEOSERVER_HOME}" "${EXTRA_CONFIG_DIR}"  /usr/share/fonts/ /scripts /tomcat_apps.zip /var/log \
/tmp/ "${GEOWEBCACHE_CACHE_DIR}";chmod o+rw "${CERT_DIR}";chmod 400 ${CATALINA_HOME}/conf/*

exec gosu ${USER_NAME} /usr/local/tomcat/bin/catalina.sh run

