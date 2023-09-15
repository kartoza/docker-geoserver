#!/bin/bash
set -e

source /root/.bashrc
# Customised entrypoint

figlet -t "Kartoza Docker GeoServer for GeoNode"

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
if ! id -u "${USER_NAME}" >/dev/null 2>&1; then
    useradd -l -m -d /home/"${USER_NAME}"/ -u "${USER_ID}" --gid "${GROUP_ID}" -s /bin/bash -G "${GEO_GROUP_NAME}" "${USER_NAME}"
fi

# Create directories
source /scripts/functions.sh
source /scripts/env-data.sh

path_envs=("${GEOSERVER_DATA_DIR}" "${CERT_DIR}" "${FOOTPRINTS_DATA_DIR}" "${FONTS_DIR}" "${GEOWEBCACHE_CACHE_DIR}" "${GEOSERVER_HOME}" "${EXTRA_CONFIG_DIR}")
for dir_names in "${path_envs[@]}";do
  create_dir "${dir_names}"
done


# Run start logic
/bin/bash /usr/local/tomcat/tmp/start.sh

# end customised entrypoint

# control the value of DOCKER_HOST_IP variable
if [ -z ${DOCKER_HOST_IP} ]
then

    echo "DOCKER_HOST_IP is empty so I'll run the python utility \n"
    echo export DOCKER_HOST_IP=`python3 /usr/local/tomcat/tmp/get_dockerhost_ip.py` >> /root/.override_env
    echo "The calculated value is now DOCKER_HOST_IP='$DOCKER_HOST_IP' \n"

else

    echo "DOCKER_HOST_IP is filled so I'll leave the found value '$DOCKER_HOST_IP' \n"

fi

# control the values of LB settings if present
if [ ${GEONODE_LB_HOST_IP} ]
then

    echo "GEONODE_LB_HOST_IP is filled so I replace the value of '$DOCKER_HOST_IP' with '$GEONODE_LB_HOST_IP' \n"
    echo export DOCKER_HOST_IP=${GEONODE_LB_HOST_IP} >> /root/.override_env

fi

if [ ${GEONODE_LB_PORT} ]
then

    echo "GEONODE_LB_PORT is filled so I replace the value of '$PUBLIC_PORT' with '$GEONODE_LB_PORT' \n"
    echo export PUBLIC_PORT=${GEONODE_LB_PORT} >> /root/.override_env

fi



# control the value of NGINX_BASE_URL variable
if [ -z `echo ${NGINX_BASE_URL} | sed 's/http:\/\/\([^:]*\).*/\1/'` ]
then
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

if ! [ -f ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/config.xml ]
then

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
#TAGNAME=( "accessTokenUri" "userAuthorizationUri" "redirectUri" "checkTokenEndpointUrl" "logoutUri" )

# backup geonode-oauth2 config.xml
cp ${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml ${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml.orig
# run the setting script for geonode-oauth2
# If it doesn't exists, copy from /settings directory if exists
if [[ "${GEONODE_PROXY_HEADERS}" =~ [Tt][Rr][Uu][Ee] ]]; then
  if [[ -f ${EXTRA_CONFIG_DIR}/config.xml  ]]; then
    envsubst < "${EXTRA_CONFIG_DIR}"/config.xml > ${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml
  else
    # Auth config
    oauth_config="${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml"
    sed -E -i "s/<cliendId>[^<]*<\/cliendId>/<cliendId>${OAUTH2_CLIENT_ID}<\/cliendId>/; s/<clientSecret>[^<]*<\/clientSecret>/<clientSecret>${OAUTH2_CLIENT_SECRET}<\/clientSecret>/" ${oauth_config}
    SITE_URL=$(echo "${SITEURL}" | sed 's#/$##')
    sed -i "s#<accessTokenUri>http://localhost:8000/o/token/#<accessTokenUri>${NGINX_BASE_URL}/o/token/#" ${oauth_config}
    sed -i "s#<userAuthorizationUri>http://localhost:8000/o/authorize/#<userAuthorizationUri>${SITE_URL}/o/authorize/#" ${oauth_config}
    sed -i "s#<redirectUri>http://localhost:8080/geoserver/index.html#<redirectUri>${SITE_URL}/geoserver/index.html#" ${oauth_config}
    sed -i "s#<checkTokenEndpointUrl>http://localhost:8000/api/o/v4/tokeninfo/#<checkTokenEndpointUrl>${SITE_URL}/api/o/v4/tokeninfo/#" ${oauth_config}
    sed -i "s#<logoutUri>http://localhost:8000/account/logout/#<logoutUri>${SITE_URL}/account/logout/#" ${oauth_config}
  fi
fi

# backup global.xml
cp ${GEOSERVER_DATA_DIR}/global.xml ${GEOSERVER_DATA_DIR}/global.xml.orig
# run the setting script for global configuration
sed -i "s#<proxyBaseUrl>http://localhost:8080/geoserver#<proxyBaseUrl>${SITE_URL}/geoserver#" ${GEOSERVER_DATA_DIR}/global.xml

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


# start tomcat
export GEOSERVER_OPTS="-Djava.awt.headless=true -Xms${INITIAL_MEMORY} -Xmx${MAXIMUM_MEMORY} \
                    -Dgwc.context.suffix=gwc -XX:+UnlockDiagnosticVMOptions \
                    -XX:+LogVMOutput -XX:LogFile=/var/log/jvm.log \
                    -XX:PerfDataSamplingInterval=500 \
                    -XX:SoftRefLRUPolicyMSPerMB=36000 \
                    -XX:-UseGCOverheadLimit -XX:+UseConcMarkSweepGC \
                    -XX:ParallelGCThreads=20 \
                    -Dfile.encoding=${ENCODING} \
                    -Djavax.servlet.request.encoding=${CHARACTER_ENCODING} \
                    -Djavax.servlet.response.encoding=${CHARACTER_ENCODING} \
                    -Duser.timezone=${TIMEZONE} \
                    -Dorg.geotools.shapefile.datetime=${USE_DATETIME_IN_SHAPEFILE} \
                    -DGS-SHAPEFILE-CHARSET=UTF-8 \
                    -DGEOSERVER_CSRF_DISABLED=true \
                    -DPRINT_BASE_URL=${PRINT_BASE_URL} \
                    -DALLOW_ENV_PARAMETRIZATION=${PROXY_BASE_URL_PARAMETRIZATION} \
                    -Xbootclasspath/a:/usr/local/tomcat/webapps/geoserver/WEB-INF/lib/marlin-render.jar \
                    -Dsun.java2d.renderer=org.marlin.pisces.MarlinRenderingEngine \
                    -Duser.language=${LANGUAGE} \
                    -Duser.region=${REGION} \
                    -Duser.country=${COUNTRY} \
                    -DENABLE_JSONP=${ENABLE_JSONP} \
                    -DMAX_FILTER_RULES=${MAX_FILTER_RULES} \
                    -DOPTIMIZE_LINE_WIDTH=${OPTIMIZE_LINE_WIDTH} \
                    -DGEOSERVER_DATA_DIR=${GEOSERVER_DATA_DIR} \
                    -DGEOSERVER_FILEBROWSER_HIDEFS=${GEOSERVER_FILEBROWSER_HIDEFS} \
                    -Dgeoserver.login.autocomplete=${LOGIN_STATUS} \
                    -DUPDATE_BUILT_IN_LOGGING_PROFILES=${UPDATE_LOGGING_PROFILES} \
                    -DRELINQUISH_LOG4J_CONTROL=${RELINQUISH_LOG4J_CONTROL} \
                    -DGEOSERVER_CONSOLE_DISABLED=${DISABLE_WEB_INTERFACE} \
                    -DGEOSERVER_CSRF_WHITELIST=${CSRF_WHITELIST} \
                    -Dgeoserver.xframe.shouldSetPolicy=${XFRAME_OPTIONS} \
                    ${ADDITIONAL_JAVA_STARTUP_OPTIONS}"
## Prepare the JVM command line arguments
export JAVA_OPTS="${JAVA_OPTS} ${GEOSERVER_OPTS}"

function directory_checker() {
  DATA_PATH=$1
  if [ -d "$DATA_PATH" ];then
    DB_USER_PERM=$(stat -c '%U' "${DATA_PATH}")
    DB_GRP_PERM=$(stat -c '%G' "${DATA_PATH}")
    if [[ ${DB_USER_PERM} != "${USER}" ]] &&  [[ ${DB_GRP_PERM} != "${GROUP}"  ]];then
      chown -R "${USER}":"${GROUP}" "${DATA_PATH}"
    fi
  fi

}

function non_root_permission() {
  USER="$1"
  GROUP="$2"
  path_envs=("${CATALINA_HOME}" /home/"${USER_NAME}"/ "${COMMUNITY_PLUGINS_DIR}" "${STABLE_PLUGINS_DIR}" "${GEOSERVER_HOME}" "/usr/share/fonts/" "/scripts" "/tmp/" "${FOOTPRINTS_DATA_DIR}" "${CERT_DIR}" "${FONTS_DIR}" "${EXTRA_CONFIG_DIR}")
  for dir_names in "${path_envs[@]}";do
	    directory_checker "${dir_names}"
  done
  chmod o+rw "${CERT_DIR}"
  gwc_file_perms
  chmod 400 ${CATALINA_HOME}/conf/*
}
if [[ ${RUN_AS_ROOT} =~ [Ff][Aa][Ll][Ss][Ee] ]];then
  non_root_permission "${USER_NAME}" "${GEO_GROUP_NAME}"

  exec gosu ${USER_NAME} /usr/local/tomcat/bin/catalina.sh run
else
  exec  /usr/local/tomcat/bin/catalina.sh run
fi