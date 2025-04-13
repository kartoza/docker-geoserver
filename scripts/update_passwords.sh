#!/bin/bash

# Credits https://github.com/geosolutions-it/docker-geoserver for this script that allows a user to pass a password
# or username on runtime.

# Source the functions from other bash scripts

source /scripts/env-data.sh
source /scripts/functions.sh

# Setup install directory
GEOSERVER_INSTALL_DIR="$(detect_install_dir)"



if [[ "${USE_DEFAULT_CREDENTIALS}" =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
  USERS_XML=${USERS_XML:-${GEOSERVER_DATA_DIR}/security/usergroup/default/users.xml}
  ROLES_XML=${ROLES_XML:-${GEOSERVER_DATA_DIR}/security/role/default/roles.xml}
  CLASSPATH=${CLASSPATH:-${GEOSERVER_INSTALL_DIR}/webapps/${GEOSERVER_CONTEXT_ROOT}/WEB-INF/lib/}

  function password_reset() {
    cp -r ${CATALINA_HOME}/security ${GEOSERVER_DATA_DIR}

      # Set random password if none provided
      file_env 'GEOSERVER_ADMIN_PASSWORD'
      if [[ -z ${GEOSERVER_ADMIN_PASSWORD} ]]; then
            generate_random_string 15
            GEOSERVER_ADMIN_PASSWORD=${RAND}
            echo $GEOSERVER_ADMIN_PASSWORD >${GEOSERVER_DATA_DIR}/security/pass.txt
            if [[ ${SHOW_PASSWORD} =~ [Tt][Rr][Uu][Ee] ]];then
              echo -e "\e[32m -------------------------------------------------------------------------------- \033[0m"
              echo -e "[Entrypoint] GENERATED GeoServer Random PASSWORD is: \e[1;31m $GEOSERVER_ADMIN_PASSWORD \033[0m"
            fi
            echo "GEOSERVER_ADMIN_PASSWORD" >> /tmp/set_vars.txt
            unset RAND
      fi

      # Get current GeoServer admin user
      file_env GEOSERVER_ADMIN_USER

      # If GEOSERVER_ADMIN_USER is set (not empty), set GEOSERVER_ADMIN_DEFAULT_USER
      if [ -n "${GEOSERVER_ADMIN_USER}" ]; then
          export GEOSERVER_ADMIN_DEFAULT_USER="$GEOSERVER_ADMIN_USER"
      else
          GEOSERVER_ADMIN_USER='admin'
          export GEOSERVER_ADMIN_DEFAULT_USER="$GEOSERVER_ADMIN_USER"
      fi

      # Get encrypted admin password
      #export GEOSERVER_ADMIN_DEFAULT_ENCRYPTED_PASSWORD="$(sed -n 's/.*password="\([^"]*\)".*/\1/p' ${USERS_XML})"

      export PWD_HASH=$(make_hash $GEOSERVER_ADMIN_PASSWORD $CLASSPATH $HASHING_ALGORITHM)
      ESCAPED_GEOSERVER_ADMIN_USER=$(printf '%s\n' "$GEOSERVER_ADMIN_DEFAULT_USER" | sed 's/[&/\]/\\&/g')
      ESCAPED_PWD_HASH=$(printf '%s\n' "$PWD_HASH" | sed 's/[&/\]/\\&/g')
      sed -i "s/name=\"[^\"]*\"/name=\"$ESCAPED_GEOSERVER_ADMIN_USER\"/; s/password=\"[^\"]*\"/password=\"$ESCAPED_PWD_HASH\"/" $USERS_XML

      # Set password encoding
      sed -i 's/pbePasswordEncoder/strongPbePasswordEncoder/g' ${GEOSERVER_DATA_DIR}/security/config.xml

      # roles.xml setup
      cp $ROLES_XML $ROLES_XML.orig
      # <userRoles username="admin">
      cat $ROLES_XML.orig | sed -e "s/ username=\"${GEOSERVER_ADMIN_DEFAULT_USER}\"/ username=\"${GEOSERVER_ADMIN_USER}\"/" > $ROLES_XML


  } # end password reset

  if [[ -f ${USERS_XML} ]]; then
    user_count=$(grep -o '<user ' ${USERS_XML} | wc -l)
    if [[ "$user_count" -gt 1 ]]; then
      echo "More than one user exists. Do not update passwords"
    else
      password_reset
    fi
  else
    echo "Setting password for the first time"
    password_reset
  fi


else
  cp -r ${CATALINA_HOME}/security ${GEOSERVER_DATA_DIR}
  sed -i 's/pbePasswordEncoder/strongPbePasswordEncoder/g' ${GEOSERVER_DATA_DIR}/security/config.xml

# end final if
fi

# Get values from settings and use them instead of setting them
if [[ -f ${EXTRA_CONFIG_DIR}/users.xml ]]; then
      cp ${EXTRA_CONFIG_DIR}/users.xml ${GEOSERVER_DATA_DIR}/security/usergroup/default/
fi
if [[ -f ${EXTRA_CONFIG_DIR}/roles.xml ]]; then
      cp ${EXTRA_CONFIG_DIR}/roles.xml ${GEOSERVER_DATA_DIR}/security/role/default/roles.xml
fi


if [[ -f /tmp/set_vars.txt ]];then
  for vars in $(cat /tmp/set_vars.txt);do unset $vars;done
  rm /tmp/set_vars.txt
fi