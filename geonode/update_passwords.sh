#!/bin/bash

if [ ${DEBUG} ]; then
    set -e
    set -x
fi;

GEOSERVER_ADMIN_USER=${GEOSERVER_ADMIN_USER:-admin}
GEOSERVER_ADMIN_PASSWORD=${GEOSERVER_ADMIN_PASSWORD:-geoserver}
USERS_XML=${USERS_XML:-/geoserver_data/data/security/usergroup/default/users.xml}
CLASSPATH=${CLASSPATH:-/usr/local/tomcat/webapps/geoserver/WEB-INF/lib/}

make_hash(){
    NEW_PASSWORD=$1
    (echo "digest1:" && java -classpath ${CLASSPATH}jasypt-1.8.jar org.jasypt.intf.cli.JasyptStringDigestCLI digest.sh algorithm=SHA-256 saltSizeBytes=16 iterations=100000 input="$NEW_PASSWORD" verbose=0) | tr -d '\n'
}

PWD_HASH=$(make_hash $GEOSERVER_ADMIN_PASSWORD)
cp $USERS_XML $USERS_XML.orig

# <user enabled="true" name="admin" password="digest1:7/qC5lIvXIcOKcoQcCyQmPK8NCpsvbj6PcS/r3S7zqDEsIuBe731ZwpTtcSe9IiK"/>

cat $USERS_XML.orig | sed -e "s/ name=\".*\" / name=\"${GEOSERVER_ADMIN_USER}\" /" | sed -e "s/ password=\".*\"/ password=\"${PWD_HASH//\//\\/}\"/" > $USERS_XML
