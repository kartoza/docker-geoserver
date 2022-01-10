#!/bin/bash

# Credits https://github.com/geosolutions-it/docker-geoserver for this script that allows a user to pass a password
# or username on runtime.

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
# check if the roles and users files already exist
if [[ ! -f ${GEOSERVER_DATA_DIR}/security/usergroup/default/users.xml || ! -f ${GEOSERVER_DATA_DIR}/security/role/default/roles.xml ]]; then
  cp -r ${CATALINA_HOME}/security ${GEOSERVER_DATA_DIR}
fi

# Set random password if none provided
if [[ -z ${GEOSERVER_ADMIN_PASSWORD} ]]; then
      generate_random_string 15
      GEOSERVER_ADMIN_PASSWORD=${RAND}
      echo $GEOSERVER_ADMIN_PASSWORD >${GEOSERVER_DATA_DIR}/security/pass.txt
fi



USERS_XML=${USERS_XML:-${GEOSERVER_DATA_DIR}/security/usergroup/default/users.xml}
ROLES_XML=${ROLES_XML:-${GEOSERVER_DATA_DIR}/security/role/default/roles.xml}
CLASSPATH=${CLASSPATH:-${GEOSERVER_INSTALL_DIR}/webapps/geoserver/WEB-INF/lib/}


# users.xml setup
cp $USERS_XML $USERS_XML.orig


if [[ -f  "${EXTRA_CONFIG_DIR}"/.default_admin_user.txt ]];then
    GEOSERVER_ADMIN_DEFAULT_USER=$(cat "${EXTRA_CONFIG_DIR}"/.default_admin_user.txt)
else
    GEOSERVER_ADMIN_DEFAULT_USER=admin
fi

if [[ -f "${EXTRA_CONFIG_DIR}"/.default_admin_encrypted_pass.txt ]];then
    GEOSERVER_ADMIN_DEFAULT_ENCRYPTED_PASSWORD=$(cat "${EXTRA_CONFIG_DIR}"/.default_admin_encrypted_pass.txt)
else
    GEOSERVER_ADMIN_DEFAULT_PASSWORD=$(grep -o 'password=\".*\"' ${CATALINA_HOME}/security/usergroup/default/users.xml|awk -F':' '{print $2}')
    GEOSERVER_ADMIN_DEFAULT_ENCRYPTED_PASSWORD="digest1:${GEOSERVER_ADMIN_DEFAULT_PASSWORD%?}"
fi

HASHING_ALGORITHM='SHA-256'

# Run password encryption once for the first runtime
SETUP_LOCKFILE="${EXTRA_CONFIG_DIR}/.first_time_hash.lock"
if [[ ! -f "${SETUP_LOCKFILE}"  ]]; then
	export PWD_HASH=$(make_hash $GEOSERVER_ADMIN_PASSWORD $CLASSPATH $HASHING_ALGORITHM)
	cat $USERS_XML.orig | sed -e "s/ name=\"${GEOSERVER_ADMIN_DEFAULT_USER}\" / name=\"${GEOSERVER_ADMIN_USER}\" /" | sed -e "s/ password=\"${GEOSERVER_ADMIN_DEFAULT_ENCRYPTED_PASSWORD//\//\\/}\"/ password=\"${PWD_HASH//\//\\/}\"/" > $USERS_XML
	touch ${SETUP_LOCKFILE}
fi

if [[ -f "${EXTRA_CONFIG_DIR}"/.default_admin_pass.txt ]];then
    if [[ $(cat "${EXTRA_CONFIG_DIR}"/.default_admin_pass.txt) != ${GEOSERVER_ADMIN_PASSWORD} ]];then
        export PWD_HASH=$(make_hash $GEOSERVER_ADMIN_PASSWORD $CLASSPATH $HASHING_ALGORITHM)
        cat $USERS_XML.orig | sed -e "s/ name=\"${GEOSERVER_ADMIN_DEFAULT_USER}\" / name=\"${GEOSERVER_ADMIN_USER}\" /" | sed -e "s/ password=\"${GEOSERVER_ADMIN_DEFAULT_ENCRYPTED_PASSWORD//\//\\/}\"/ password=\"${PWD_HASH//\//\\/}\"/" > $USERS_XML
    fi
fi

# roles.xml setup
cp $ROLES_XML $ROLES_XML.orig
# <userRoles username="admin">
cat $ROLES_XML.orig | sed -e "s/ username=\"${GEOSERVER_ADMIN_DEFAULT_USER}\"/ username=\"${GEOSERVER_ADMIN_USER}\"/" > $ROLES_XML

# Set default passwords
echo "${GEOSERVER_ADMIN_USER}" > "${EXTRA_CONFIG_DIR}"/.default_admin_user.txt
echo "${PWD_HASH}" > "${EXTRA_CONFIG_DIR}"/.default_admin_encrypted_pass.txt
echo ${GEOSERVER_ADMIN_PASSWORD} > "${EXTRA_CONFIG_DIR}"/.default_admin_pass.txt

# Write GeoServer Admin password only if we are setting a random password
if [[ -f ${GEOSERVER_DATA_DIR}/security/pass.txt ]];then
    echo -e "[Entrypoint] GENERATED GeoServer  PASSWORD: \e[1;31m $GEOSERVER_ADMIN_PASSWORD \033[0m"
fi

# Reset Admin credentials will reset everything to the default passwords and username
if [[ "${RESET_ADMIN_CREDENTIALS}" =~ [Tt][Rr][Uu][Ee] ]]; then
    cp -r ${CATALINA_HOME}/security ${GEOSERVER_DATA_DIR}
fi

