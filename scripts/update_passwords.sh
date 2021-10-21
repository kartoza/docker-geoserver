#!/bin/bash


# Credits https://github.com/geosolutions-it/docker-geoserver for this script that allows a user to pass a password
# or username on runtime.
SETUP_LOCKFILE="${GEOSERVER_DATA_DIR}/.updatepassword.lock"
# Reset Admin credentials
if [[ "${RESET_ADMIN_CREDENTIALS}" =~ [Tt][Rr][Uu][Ee] ]]; then
  if [[ -f "${SETUP_LOCKFILE}" ]];then
        rm ${SETUP_LOCKFILE}
  fi
  cp -r ${CATALINA_HOME}/security ${GEOSERVER_DATA_DIR}
fi


if [[ -f "${SETUP_LOCKFILE}"  ]]; then
	exit 0
fi

# Source the functions from other bash scripts

source /scripts/env-data.sh
source /scripts/functions.sh



# Setup install directory
if [[ -f ${GEOSERVER_HOME}/start.jar ]]; then
   GEOSERVER_INSTALL_DIR=${GEOSERVER_HOME}
else
  GEOSERVER_INSTALL_DIR=${CATALINA_HOME}
fi


# Copy security configs
if [ ! -d "${GEOSERVER_DATA_DIR}/security" ]; then
  cp -r ${CATALINA_HOME}/security ${GEOSERVER_DATA_DIR}
fi




# Set random password if none provided
if [[ -z ${GEOSERVER_ADMIN_PASSWORD} ]]; then
      if [[ "${RESET_ADMIN_CREDENTIALS}" =~ [Tt][Rr][Uu][Ee] ]];then
        delete_file /scripts/.pass_15.txt
      fi
      generate_random_string 15
      GEOSERVER_ADMIN_PASSWORD=${RAND}
      echo $GEOSERVER_ADMIN_PASSWORD >${GEOSERVER_DATA_DIR}/security/pass.txt
fi


USERS_XML=${USERS_XML:-${GEOSERVER_DATA_DIR}/security/usergroup/default/users.xml}
ROLES_XML=${ROLES_XML:-${GEOSERVER_DATA_DIR}/security/role/default/roles.xml}
CLASSPATH=${CLASSPATH:-${GEOSERVER_INSTALL_DIR}/webapps/geoserver/WEB-INF/lib/}

make_hash(){
    NEW_PASSWORD=$1
    (echo "digest1:" && java -classpath $(find $CLASSPATH -regex ".*jasypt-[0-9]\.[0-9]\.[0-9].*jar") org.jasypt.intf.cli.JasyptStringDigestCLI digest.sh algorithm=SHA-256 saltSizeBytes=16 iterations=100000 input="$NEW_PASSWORD" verbose=0) | tr -d '\n'
}

PWD_HASH=$(make_hash $GEOSERVER_ADMIN_PASSWORD)

# users.xml setup
cp $USERS_XML $USERS_XML.orig

# <user enabled="true" name="admin" password="digest1:7/qC5lIvXIcOKcoQcCyQmPK8NCpsvbj6PcS/r3S7zqDEsIuBe731ZwpTtcSe9IiK"/>
cat $USERS_XML.orig | sed -e "s/ name=\".*\" / name=\"${GEOSERVER_ADMIN_USER}\" /" | sed -e "s/ password=\".*\"/ password=\"${PWD_HASH//\//\\/}\"/" > $USERS_XML


# roles.xml setup
cp $ROLES_XML $ROLES_XML.orig
# <userRoles username="admin">
cat $ROLES_XML.orig | sed -e "s/ username=\".*\"/ username=\"${GEOSERVER_ADMIN_USER}\"/" > $ROLES_XML

# Write GeoServer Admin password only if we are setting a random password
if [[ -f ${GEOSERVER_DATA_DIR}/security/pass.txt ]];then
echo -e "[Entrypoint] GENERATED GeoServer  PASSWORD: \e[1;31m $GEOSERVER_ADMIN_PASSWORD"
echo -e "\033[0m "
fi

# Put lock file to make sure password is not reinitialized on restart
touch ${SETUP_LOCKFILE}