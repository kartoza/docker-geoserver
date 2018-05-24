#!/bin/bash
set -e

source /root/.bashrc

# control the value of DOCKER_HOST_IP variable
if [ -z ${DOCKER_HOST_IP} ]
then

    echo "DOCKER_HOST_IP is empty so I'll run the python utility \n" >> /usr/local/tomcat/tmp/set_geoserver_auth.log
    echo export DOCKER_HOST_IP=`python /usr/local/tomcat/tmp/get_dockerhost_ip.py` >> /root/.override_env
    echo "The calculated value is now DOCKER_HOST_IP='$DOCKER_HOST_IP' \n" >> /usr/local/tomcat/tmp/set_geoserver_auth.log

else

    echo "DOCKER_HOST_IP is filled so I'll leave the found value '$DOCKER_HOST_IP' \n" >> /usr/local/tomcat/tmp/set_geoserver_auth.log

fi

# control the values of LB settings if present
if [ ${GEONODE_LB_HOST_IP} ]
then

    echo "GEONODE_LB_HOST_IP is filled so I replace the value of '$DOCKER_HOST_IP' with '$GEONODE_LB_HOST_IP' \n" >> /usr/local/tomcat/tmp/set_geoserver_auth.log
    echo export DOCKER_HOST_IP=${GEONODE_LB_HOST_IP} >> /root/.override_env

fi

if [ ${GEONODE_LB_PORT} ]
then

    echo "GEONODE_LB_PORT is filled so I replace the value of '$PUBLIC_PORT' with '$GEONODE_LB_PORT' \n" >> /usr/local/tomcat/tmp/set_geoserver_auth.log
    echo export PUBLIC_PORT=${GEONODE_LB_PORT} >> /root/.override_env

fi

# control the value of NGINX_BASE_URL variable
if [ -z `echo ${NGINX_BASE_URL} | sed 's/http:\/\/\([^:]*\).*/\1/'` ]
then

    echo "NGINX_BASE_URL is empty so I'll run the python utility \n" >> /usr/local/tomcat/tmp/set_geoserver_auth.log
    echo export NGINX_BASE_URL=`python /usr/local/tomcat/tmp/get_nginxhost_ip.py` >> /root/.override_env
    echo "The calculated value is now NGINX_BASE_URL='$NGINX_BASE_URL' \n" >> /usr/local/tomcat/tmp/set_geoserver_auth.log

else

    echo "NGINX_BASE_URL is filled so I'll leave the found value '$NGINX_BASE_URL' \n" >> /usr/local/tomcat/tmp/set_geoserver_auth.log

fi

# set basic tagname
TAGNAME=( "baseUrl" )

if ! [ -f ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/config.xml ]
then

    echo "Configuration file '$GEOSERVER_DATA_DIR'/security/auth/geonodeAuthProvider/config.xml is not available so it is gone to skip \n" >> /usr/local/tomcat/tmp/set_geoserver_auth.log

else

    # backup geonodeAuthProvider config.xml
    cp ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/config.xml ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/config.xml.orig
    # run the setting script for geonodeAuthProvider
    /usr/local/tomcat/tmp/set_geoserver_auth.sh ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/config.xml ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/ ${TAGNAME} >> /usr/local/tomcat/tmp/set_geoserver_auth.log

fi

# backup geonode REST role service config.xml
cp "${GEOSERVER_DATA_DIR}/security/role/geonode REST role service/config.xml" "${GEOSERVER_DATA_DIR}/security/role/geonode REST role service/config.xml.orig"
# run the setting script for geonode REST role service
/usr/local/tomcat/tmp/set_geoserver_auth.sh "${GEOSERVER_DATA_DIR}/security/role/geonode REST role service/config.xml" "${GEOSERVER_DATA_DIR}/security/role/geonode REST role service/" ${TAGNAME} >> /usr/local/tomcat/tmp/set_geoserver_auth.log

# set oauth2 filter tagname
TAGNAME=( "accessTokenUri" "userAuthorizationUri" "redirectUri" "checkTokenEndpointUrl" "logoutUri" )

# backup geonode-oauth2 config.xml
cp ${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml ${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml.orig
# run the setting script for geonode-oauth2
/usr/local/tomcat/tmp/set_geoserver_auth.sh ${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml ${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/ "${TAGNAME[@]}" >> /usr/local/tomcat/tmp/set_geoserver_auth.log

# set global tagname
TAGNAME=( "proxyBaseUrl" )

# backup global.xml
cp ${GEOSERVER_DATA_DIR}/global.xml ${GEOSERVER_DATA_DIR}/global.xml.orig
# run the setting script for global configuration
/usr/local/tomcat/tmp/set_geoserver_auth.sh ${GEOSERVER_DATA_DIR}/global.xml ${GEOSERVER_DATA_DIR}/ ${TAGNAME} >> /usr/local/tomcat/tmp/set_geoserver_auth.log

# start tomcat
exec catalina.sh run
