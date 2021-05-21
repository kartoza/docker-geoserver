#!/bin/bash
set -e

source ${GEOSERVER_HOME}/.bashrc

/scripts/start.sh

if [[ ${GEONODE} =~ [Tt][Rr][Uu][Ee] ]];then

  # control the value of DOCKER_HOST_IP variable
  if [ -z ${DOCKER_HOST_IP} ]
  then

      echo "DOCKER_HOST_IP is empty so I'll run the python3 utility \n" >> /geonode_scripts/set_geoserver_auth.log
      echo export DOCKER_HOST_IP=`python3 /geonode_scripts/get_dockerhost_ip.py` >> ${GEOSERVER_HOME}/.override_env
      echo "The calculated value is now DOCKER_HOST_IP='$DOCKER_HOST_IP' \n" >> /geonode_scripts/set_geoserver_auth.log

  else

      echo "DOCKER_HOST_IP is filled so I'll leave the found value '$DOCKER_HOST_IP' \n" >> /geonode_scripts/set_geoserver_auth.log

  fi

  # control the values of LB settings if present
  if [ ${GEONODE_LB_HOST_IP} ]
  then

      echo "GEONODE_LB_HOST_IP is filled so I replace the value of '$DOCKER_HOST_IP' with '$GEONODE_LB_HOST_IP' \n" >> /geonode_scripts/set_geoserver_auth.log
      echo export DOCKER_HOST_IP=${GEONODE_LB_HOST_IP} >> ${GEOSERVER_HOME}/.override_env

  fi

  if [ ${GEONODE_LB_PORT} ]
  then

      echo "GEONODE_LB_PORT is filled so I replace the value of '$PUBLIC_PORT' with '$GEONODE_LB_PORT' \n" >> /geonode_scripts/set_geoserver_auth.log
      echo export PUBLIC_PORT=${GEONODE_LB_PORT} >> ${GEOSERVER_HOME}/.override_env

  fi


  # control the value of NGINX_BASE_URL variable
  if [ -z `echo ${NGINX_BASE_URL} | sed 's/http:\/\/\([^:]*\).*/\1/'` ]
  then

      echo "NGINX_BASE_URL is empty so I'll use the static nginx hostname \n" >> /geonode_scripts/set_geoserver_auth.log
      # echo export NGINX_BASE_URL=`python3 /geonode_scripts/get_nginxhost_ip.py` >>${GEOSERVER_HOME}/.override_env
      # TODO rework get_nginxhost_ip to get URL with static hostname from nginx service name
      # + exposed port of that container i.e. http://geonode:80
      echo export NGINX_BASE_URL=http://geonode:80 >> ${GEOSERVER_HOME}/.override_env
      echo "The calculated value is now NGINX_BASE_URL='$NGINX_BASE_URL' \n" >> /geonode_scripts/set_geoserver_auth.log

  else

      echo "NGINX_BASE_URL is filled so I'll leave the found value '$NGINX_BASE_URL' \n" >> /geonode_scripts/set_geoserver_auth.log

  fi

  # set basic tagname
  TAGNAME=( "baseUrl" )

  if ! [ -f ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/config.xml ]
  then

      echo "Configuration file '$GEOSERVER_DATA_DIR'/security/auth/geonodeAuthProvider/config.xml is not available so it is gone to skip \n" >> /geonode_scripts/set_geoserver_auth.log

  else

      # backup geonodeAuthProvider config.xml
      cp ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/config.xml ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/config.xml.orig
      # run the setting script for geonodeAuthProvider
      /geonode_scripts/set_geoserver_auth.sh ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/config.xml ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/ ${TAGNAME} >> /geonode_scripts/set_geoserver_auth.log

  fi

  # backup geonode REST role service config.xml
  cp "${GEOSERVER_DATA_DIR}/security/role/geonode REST role service/config.xml" "${GEOSERVER_DATA_DIR}/security/role/geonode REST role service/config.xml.orig"
  # run the setting script for geonode REST role service
  /geonode_scripts/set_geoserver_auth.sh "${GEOSERVER_DATA_DIR}/security/role/geonode REST role service/config.xml" "${GEOSERVER_DATA_DIR}/security/role/geonode REST role service/" ${TAGNAME} >> /geonode_scripts/set_geoserver_auth.log

  # set oauth2 filter tagname
  TAGNAME=( "accessTokenUri" "userAuthorizationUri" "redirectUri" "checkTokenEndpointUrl" "logoutUri" )

  # backup geonode-oauth2 config.xml
  cp ${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml ${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml.orig
  # run the setting script for geonode-oauth2
  /geonode_scripts/set_geoserver_auth.sh ${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml ${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/ "${TAGNAME[@]}" >> /geonode_scripts/set_geoserver_auth.log

  # set global tagname
  TAGNAME=( "proxyBaseUrl" )

  # backup global.xml
  cp ${GEOSERVER_DATA_DIR}/global.xml ${GEOSERVER_DATA_DIR}/global.xml.orig
  # run the setting script for global configuration
  /geonode_scripts/set_geoserver_auth.sh ${GEOSERVER_DATA_DIR}/global.xml ${GEOSERVER_DATA_DIR}/ ${TAGNAME} >> /geonode_scripts/set_geoserver_auth.log

  # set correct amqp broker url
  sed -i -e 's/localhost/rabbitmq/g' ${GEOSERVER_DATA_DIR}/notifier/notifier.xml

  # exclude wrong dependencies
  sed -i -e 's/xom-\*\.jar/xom-\*\.jar,bcprov\*\.jar/g' /usr/local/tomcat/conf/catalina.properties

fi

CLUSTER_CONFIG_DIR="${GEOSERVER_DATA_DIR}/cluster/instance_$RANDOMSTRING"
MONITOR_AUDIT_PATH="${GEOSERVER_DATA_DIR}/monitoring/monitor_$RANDOMSTRING"

export GEOSERVER_OPTS="-Djava.awt.headless=true -server -Xms${INITIAL_MEMORY} -Xmx${MAXIMUM_MEMORY} \
       -XX:PerfDataSamplingInterval=500 -Dorg.geotools.referencing.forceXY=true \
       -XX:SoftRefLRUPolicyMSPerMB=36000  -XX:NewRatio=2 \
       -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=20 -XX:ConcGCThreads=5 \
       -XX:InitiatingHeapOccupancyPercent=70 -XX:+CMSClassUnloadingEnabled \
       -Djts.overlay=ng \
       -Dfile.encoding=${ENCODING} \
       -Duser.timezone=${TIMEZONE} \
       -Djavax.servlet.request.encoding=${CHARACTER_ENCODING} \
       -Djavax.servlet.response.encoding=${CHARACTER_ENCODING} \
       -DCLUSTER_CONFIG_DIR=${CLUSTER_CONFIG_DIR} \
       -DGEOSERVER_DATA_DIR=${GEOSERVER_DATA_DIR} \
       -DGEOSERVER_AUDIT_PATH=${MONITOR_AUDIT_PATH} \
       -Dorg.geotools.shapefile.datetime=true \
       -Ds3.properties.location=${GEOSERVER_DATA_DIR}/s3.properties \
       -Dsun.java2d.renderer.useThreadLocal=false \
       -Dsun.java2d.renderer.pixelsize=8192 -server -XX:NewSize=300m \
       -Dlog4j.configuration=${CATALINA_HOME}/log4j.properties \
       --patch-module java.desktop=${CATALINA_HOME}/marlin-0.9.4.2-Unsafe-OpenJDK9.jar  \
       -Dsun.java2d.renderer=org.marlin.pisces.PiscesRenderingEngine \
       -Dgeoserver.login.autocomplete=${LOGIN_STATUS} \
       -DGEOSERVER_CONSOLE_DISABLED=${WEB_INTERFACE} \
       -DGEOSERVER_CSRF_WHITELIST=${CSRF_WHITELIST} \
       -DPRINT_BASE_URL=$PRINT_CONFIG_URL \
       -Dgeoserver.xframe.shouldSetPolicy=${XFRAME_OPTIONS} "

## Preparare the JVM command line arguments
export JAVA_OPTS="${JAVA_OPTS} ${GEOSERVER_OPTS}"

if ls /geoserver/start.jar >/dev/null 2>&1; then
  cd /geoserver/
  exec java $JAVA_OPTS  -jar start.jar
else
  exec /usr/local/tomcat/bin/catalina.sh run
fi



