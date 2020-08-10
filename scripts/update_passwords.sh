#!/bin/bash
# Credits https://github.com/geosolutions-it/docker-geoserver for this script that allows a user to pass a password
# or username on runtime.
SETUP_LOCKFILE="${GEOSERVER_DATA_DIR}/.updatepassword.lock"
if [ -f "${SETUP_LOCKFILE}" ]; then
	exit 0
fi

if [ ${DEBUG} ]; then
    set -e
    set -x
fi;

if [ ! -d "${GEOSERVER_DATA_DIR}/security" ]; then
  cp -r ${CATALINA_HOME}/geoserver-data/data/security ${GEOSERVER_DATA_DIR}
fi



ADMIN_USERNAME=${ADMIN_USERNAME:-admin}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-geoserver}
USERS_XML=${USERS_XML:-${GEOSERVER_DATA_DIR}/security/usergroup/default/users.xml}
ROLES_XML=${ROLES_XML:-${GEOSERVER_DATA_DIR}/security/role/default/roles.xml}
CLASSPATH=${CLASSPATH:-${GEOSERVER_HOME}/webapps/geoserver/WEB-INF/lib/}

make_hash(){
    NEW_PASSWORD=$1
    (echo "digest1:" && java -classpath $(find $CLASSPATH -regex ".*jasypt-[0-9]\.[0-9]\.[0-9].*jar") org.jasypt.intf.cli.JasyptStringDigestCLI digest.sh algorithm=SHA-256 saltSizeBytes=16 iterations=100000 input="$NEW_PASSWORD" verbose=0) | tr -d '\n'
}

ADMIN_ENCRYPTED_PASSWORD=$(make_hash $ADMIN_PASSWORD)

# users.xml setup
cp $USERS_XML $USERS_XML.orig
# <user enabled="true" name="admin" password="digest1:7/qC5lIvXIcOKcoQcCyQmPK8NCpsvbj6PcS/r3S7zqDEsIuBe731ZwpTtcSe9IiK"/>
cat $USERS_XML.orig | sed -e "s/ name=\".*\" / name=\"${ADMIN_USERNAME}\" /" | sed -e "s/ password=\".*\"/ password=\"${ADMIN_ENCRYPTED_PASSWORD//\//\\/}\"/" > $USERS_XML

# roles.xml setup
cp $ROLES_XML $ROLES_XML.orig
# <userRoles username="admin">
cat $ROLES_XML.orig | sed -e "s/ username=\".*\"/ username=\"${ADMIN_USERNAME}\"/" > $ROLES_XML
ADMIN_ENCRYPTED_PASSWORD=""
# Put lock file to make sure password is not reinitialized on restart
touch ${SETUP_LOCKFILE}