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

SETUP_LOCKFILE="${EXTRA_CONFIG_DIR}/.first_time_hash.lock"
if [[ ${RECREATE_DATADIR} =~ [Tt][Rr][Uu][Ee] ]];then
    cp -r ${CATALINA_HOME}/security ${GEOSERVER_DATA_DIR}
    delete_file ${SETUP_LOCKFILE} && \
    delete_file "${EXTRA_CONFIG_DIR}"/.default_admin_user.txt && \
    delete_file "${EXTRA_CONFIG_DIR}"/.default_admin_encrypted_pass.txt && \
    delete_file "${EXTRA_CONFIG_DIR}"/.default_admin_pass.txt
else
    if [[ ! -f "${SETUP_LOCKFILE}"  ]]; then
        if [ ! -d "${GEOSERVER_DATA_DIR}/security" ]; then
          echo -e "\e[32m Copying default security folder \033[0m"
          cp -r ${CATALINA_HOME}/security ${GEOSERVER_DATA_DIR}
        fi
    fi
fi

# Set random password if none provided
if [[ -z ${GEOSERVER_ADMIN_PASSWORD} ]]; then
      echo -e "\e[32m ------------------------------------------ \033[0m"
      echo -e "\e[32m Set random password because none is provided \033[0m"
      generate_random_string 15
      GEOSERVER_ADMIN_PASSWORD=${RAND}
      echo $GEOSERVER_ADMIN_PASSWORD >${GEOSERVER_DATA_DIR}/security/pass.txt
      echo -e "[Entrypoint] GENERATED GeoServer  PASSWORD: \e[1;31m $GEOSERVER_ADMIN_PASSWORD \033[0m"
fi

USERS_XML=${USERS_XML:-${GEOSERVER_DATA_DIR}/security/usergroup/default/users.xml}
ROLES_XML=${ROLES_XML:-${GEOSERVER_DATA_DIR}/security/role/default/roles.xml}
CLASSPATH=${CLASSPATH:-${GEOSERVER_INSTALL_DIR}/webapps/geoserver/WEB-INF/lib/}

# users.xml setup
cp $USERS_XML $USERS_XML.orig

# Get current GeoServer admin user
if [[ -f  "${EXTRA_CONFIG_DIR}"/.default_admin_user.txt ]];then
    GEOSERVER_ADMIN_DEFAULT_USER=$(cat "${EXTRA_CONFIG_DIR}"/.default_admin_user.txt)
else
    GEOSERVER_ADMIN_DEFAULT_USER=admin
fi

# Get encrypted admin password
if [[ -f "${EXTRA_CONFIG_DIR}"/.default_admin_encrypted_pass.txt ]];then
    export GEOSERVER_ADMIN_DEFAULT_ENCRYPTED_PASSWORD=$(cat "${EXTRA_CONFIG_DIR}"/.default_admin_encrypted_pass.txt)
else
    export GEOSERVER_ADMIN_DEFAULT_PASSWORD=$(grep -o 'password=\".*\"' ${CATALINA_HOME}/security/usergroup/default/users.xml|awk -F':' '{print $2}')
    export GEOSERVER_ADMIN_DEFAULT_ENCRYPTED_PASSWORD="digest1:${GEOSERVER_ADMIN_DEFAULT_PASSWORD%?}"
fi


if [[ ! -f "${SETUP_LOCKFILE}"  ]]; then
    echo -e "\e[32m ----------------------------------------------------- \033[0m"
    echo -e "\e[32m  Run password encryption once for the first runtime \033[0m"
    export PWD_HASH=$(make_hash $GEOSERVER_ADMIN_PASSWORD $CLASSPATH $HASHING_ALGORITHM)
    cat $USERS_XML.orig | sed -e "s/ name=\"${GEOSERVER_ADMIN_DEFAULT_USER}\" / name=\"${GEOSERVER_ADMIN_USER}\" /" | sed -e "s/ password=\"${GEOSERVER_ADMIN_DEFAULT_ENCRYPTED_PASSWORD//\//\\/}\"/ password=\"${PWD_HASH//\//\\/}\"/" > $USERS_XML
    touch ${SETUP_LOCKFILE}
else

    if [[ -f "${EXTRA_CONFIG_DIR}"/.default_admin_pass.txt ]];then
        export GEOSERVER_ADMIN_PASSWORD_TEMP=$(cat "${EXTRA_CONFIG_DIR}"/.default_admin_pass.txt)

        if [[ ${GEOSERVER_ADMIN_PASSWORD_TEMP} != ${GEOSERVER_ADMIN_PASSWORD} ]];then
            echo -e "\e[32m --------------------------------------------------------- \033[0m"
            echo -e "\e[32m  (Re)setting GEOSERVER_ADMIN_PASSWORD because it has changed \033[0m"
            export PWD_HASH=$(make_hash $GEOSERVER_ADMIN_PASSWORD $CLASSPATH $HASHING_ALGORITHM)
            cat $USERS_XML.orig | sed -e "s/ name=\"${GEOSERVER_ADMIN_DEFAULT_USER}\" / name=\"${GEOSERVER_ADMIN_USER}\" /" | sed -e "s/ password=\"${GEOSERVER_ADMIN_DEFAULT_ENCRYPTED_PASSWORD//\//\\/}\"/ password=\"${PWD_HASH//\//\\/}\"/" > $USERS_XML
        fi
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

if [[ -f ${EXTRA_CONFIG_DIR}/users.xml ]]; then
    cp ${EXTRA_CONFIG_DIR}/users.xml ${GEOSERVER_DATA_DIR}/security/usergroup/default/
fi
if [[ -f ${EXTRA_CONFIG_DIR}/roles.xml ]]; then
    cp ${EXTRA_CONFIG_DIR}/roles.xml ${GEOSERVER_DATA_DIR}/security/role/default/roles.xml
fi
