#!/bin/bash

# Credits https://github.com/geosolutions-it/docker-geoserver for this script that allows a user to pass a password
# or username on runtime.

SCRIPT_DIR="/scripts"

init_sources() {
  source "${SCRIPT_DIR}/lib/env-data.sh"
  source "${SCRIPT_DIR}/lib/utils.sh"
  source "${SCRIPT_DIR}/lib/logging.sh"
  source "${SCRIPT_DIR}/lib/database.sh"
  source "${SCRIPT_DIR}/lib/geoserver.sh"
  source "${SCRIPT_DIR}/lib/tomcat.sh"
  source "${SCRIPT_DIR}/lib/cluster.sh"
}

setup_install_dir() {
  GEOSERVER_INSTALL_DIR="$(detect_install_dir)"
}

setup_security_env() {
  USERS_XML=${USERS_XML:-${GEOSERVER_DATA_DIR}/security/usergroup/default/users.xml}
  ROLES_XML=${ROLES_XML:-${GEOSERVER_DATA_DIR}/security/role/default/roles.xml}
  CLASSPATH=${CLASSPATH:-${GEOSERVER_INSTALL_DIR}/webapps/${GEOSERVER_CONTEXT_ROOT}/WEB-INF/lib/}

  file_env GEOSERVER_ADMIN_USER
  file_env 'GEOSERVER_ADMIN_PASSWORD'
}

action_password_update() {
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

  IFS=',' read -a geopass <<< "$GEOSERVER_ADMIN_PASSWORD"

  if [[ -z "${GEOSERVER_ADMIN_USER}" || "${GEOSERVER_ADMIN_USER}" =~ ^[[:space:]]*$ ]]; then
    GEOSERVER_ADMIN_USER="admin"
    echo "[INFO] Using default admin username: admin"
 fi

  IFS=',' read -a geouser <<< "$GEOSERVER_ADMIN_USER"

  export GEOSERVER_ADMIN_DEFAULT_USER='admin'

  COUNT_GEOSERVER_ADMIN_USER=$(echo "$GEOSERVER_ADMIN_USER" | tr ',' '\n' | wc -l)
  COUNT_GEOSERVER_ADMIN_PASSWORD=$(echo "$GEOSERVER_ADMIN_PASSWORD" | tr ',' '\n' | wc -l)

  if [[ ${COUNT_GEOSERVER_ADMIN_USER} -eq ${COUNT_GEOSERVER_ADMIN_PASSWORD} ]]; then
    for ((i = 0; i < ${COUNT_GEOSERVER_ADMIN_PASSWORD}; i++)); do
      user="${geouser[$i]}"
      pass="${geopass[$i]}"

      export PWD_HASH=$(make_hash "$pass" "$CLASSPATH" "$HASHING_ALGORITHM")
      ESCAPED_GEOSERVER_ADMIN_USER=$(printf '%s\n' "$user" | sed 's/[&/\]/\\&/g')
      ESCAPED_PWD_HASH=$(printf '%s\n' "$PWD_HASH" | sed 's/[&/\]/\\&/g')

      if [[ $i -eq 0 ]]; then
        sed -i "s/name=\"[^\"]*\"/name=\"$ESCAPED_GEOSERVER_ADMIN_USER\"/; s/password=\"[^\"]*\"/password=\"$ESCAPED_PWD_HASH\"/" "$USERS_XML"
        cp "$ROLES_XML" "$ROLES_XML.orig"
        sed -e "s/ username=\"${GEOSERVER_ADMIN_DEFAULT_USER}\"/ username=\"${user}\"/" "$ROLES_XML.orig" > "$ROLES_XML"
      else
        echo "[SECURITY] Adding extra admin user: $ESCAPED_GEOSERVER_ADMIN_USER"
        sed -i "/<\/users>/i \    <user enabled=\"true\" name=\"$ESCAPED_GEOSERVER_ADMIN_USER\" password=\"$ESCAPED_PWD_HASH\"/>" "$USERS_XML"
        sed -i "/<\/userList>/i \        <userRoles username=\"$ESCAPED_GEOSERVER_ADMIN_USER\">\n            <roleRef roleID=\"ADMIN\"/>\n        </userRoles>" "$ROLES_XML"
      fi
    done
  else
    echo -e "\e[32m -------------------------------------------------------------------------------- \033[0m"
    echo -e "\e[32m [Entrypoint] User/password count mismatch → skipping update and using:\033[0m \e[1;31m default credentials \033[0m"
  fi

  sed -i 's/pbePasswordEncoder/strongPbePasswordEncoder/g' ${GEOSERVER_DATA_DIR}/security/config.xml
}

password_reset() {
  if [[ ! -f ${EXTRA_CONFIG_DIR}/.security.lock ]]; then

    echo -e "\e[32m [SECURITY CONFIG] First-time initialization → copying default security configs. \033[0m"
    cp -r "${CATALINA_HOME}/security" "${GEOSERVER_DATA_DIR}"
    sed -i '/<readOnly>false<\/readOnly>/a <loginEnabled>false<\/loginEnabled>' \
      "${GEOSERVER_DATA_DIR}/security/config.xml"
    action_password_update
    touch "${EXTRA_CONFIG_DIR}/.security.lock"
  else
    create_dir "${GEOSERVER_DATA_DIR}/security"
    local did_restore=false

    case "${GEOSERVER_SECURITY_MODE}" in
      overwrite)
        echo -e "\e[32m [SECURITY CONFIG] Mode: overwrite → replacing all security configs with defaults. \033[0m"
        cp -r "${CATALINA_HOME}/security/"* "${GEOSERVER_DATA_DIR}/security/"
        did_restore=true
        ;;

      preserve|*)
        echo -e "\e[32m [SECURITY CONFIG] Mode: preserve → keeping user-modified security configs. \033[0m"

        if [ ! -d "${GEOSERVER_DATA_DIR}/security/role" ]; then
          echo -e "\e[32m [SECURITY CONFIG] role directory missing → restoring defaults. \033[0m"
          cp -r "${CATALINA_HOME}/security/role" "${GEOSERVER_DATA_DIR}/security/"
          did_restore=true
        fi

        if [ ! -d "${GEOSERVER_DATA_DIR}/security/usergroup" ]; then
          echo -e "\e[32m [SECURITY CONFIG] usergroup directory missing → restoring defaults. \033[0m"
          cp -r "${CATALINA_HOME}/security/usergroup" "${GEOSERVER_DATA_DIR}/security/"
          did_restore=true
        fi

        if [ ! -f "${GEOSERVER_DATA_DIR}/security/config.xml" ]; then
          echo -e "\e[32m [SECURITY CONFIG] config.xml missing → restoring defaults. \033[0m"
          cp "${CATALINA_HOME}/security/config.xml" "${GEOSERVER_DATA_DIR}/security/"
          did_restore=true
        fi
        ;;
    esac

    if [[ "${did_restore}" == true ]]; then
      echo -e "\e[32m [SECURITY CONFIG] Running password update because defaults were restored. \033[0m"
      action_password_update
    fi
  fi
}

apply_extra_configs() {
  if [[ -f ${EXTRA_CONFIG_DIR}/users.xml ]]; then
    cp ${EXTRA_CONFIG_DIR}/users.xml ${GEOSERVER_DATA_DIR}/security/usergroup/default/
  fi
  if [[ -f ${EXTRA_CONFIG_DIR}/roles.xml ]]; then
    cp ${EXTRA_CONFIG_DIR}/roles.xml ${GEOSERVER_DATA_DIR}/security/role/default/roles.xml
  fi
}



main() {
  init_sources
  setup_install_dir

  if [[ "${USE_DEFAULT_CREDENTIALS}" =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
    setup_security_env
    password_reset
  fi

  apply_extra_configs
  clean_up_vars
}

main "$@"