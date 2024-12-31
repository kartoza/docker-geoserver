#!/bin/bash

source /scripts/functions.sh
source /scripts/env-data.sh
GS_VERSION=$(cat /scripts/geoserver_version.txt)
STABLE_PLUGIN_BASE_URL=$(cat /scripts/geoserver_gs_url.txt)

web_cors

# Useful for development - We need a clean state of data directory
if [[ "${RECREATE_DATADIR}" =~ [Tt][Rr][Uu][Ee] ]]; then
  rm -rf "${GEOSERVER_DATA_DIR:?}/"*
fi

# install Font files in resources/fonts if they exists
if ls "${FONTS_DIR}"/*.ttf >/dev/null 2>&1; then
  cp -rf "${FONTS_DIR}"/*.ttf /usr/share/fonts/truetype/
fi

# Install opentype fonts
if ls "${FONTS_DIR}"/*.otf >/dev/null 2>&1; then
  cp -rf "${FONTS_DIR}"/*.otf /usr/share/fonts/opentype/
fi

# Install google fonts based on https://github.com/google/fonts
# ADDED env variable to allow users to pass comma separated values
if [[ ! -z  ${GOOGLE_FONTS_NAMES}  ]];then
  git clone --filter=blob:none --no-checkout https://github.com/google/fonts.git
  cd $(pwd)/fonts
  git config core.sparsecheckout true

  if [[ "$GOOGLE_FONTS_NAMES" == *,* ]]; then
    for gfont in $(echo "${GOOGLE_FONTS_NAMES}" | tr ',' ' '); do
          if grep -Fxq "$gfont" /build_data/google_fonts.txt; then
            echo ofl/$gfont >> .git/info/sparse-checkout
          fi
    done
    git checkout main
    for gfont in $(echo "${GOOGLE_FONTS_NAMES}" | tr ',' ' '); do
          if grep -Fxq "$gfont" /build_data/google_fonts.txt; then
            cp -r  ofl/"${gfont}" /usr/share/fonts/truetype/
          fi
    done

  else
    if grep -Fxq "$GOOGLE_FONTS_NAMES" /build_data/google_fonts.txt; then
      echo ofl/$GOOGLE_FONTS_NAMES >> .git/info/sparse-checkout
    fi
    git checkout main
    if grep -Fxq "$GOOGLE_FONTS_NAMES" /build_data/google_fonts.txt; then
      git sparse-checkout set ofl/$GOOGLE_FONTS_NAMES
      cp -r ofl/$GOOGLE_FONTS_NAMES /usr/share/fonts/truetype/
    fi
  fi
  cd ..
  rm -rf fonts
fi

if [[ ${LOGGING_STDOUT} =~ [Tt][Rr][Uu][Ee] ]];then
  export CONSOLE_HANDLER_LEVEL
  tomcat_logging
fi

# Add custom espg properties file or the default one
create_dir "${GEOSERVER_DATA_DIR}"/user_projections
create_dir "${GEOWEBCACHE_CACHE_DIR}"


setup_custom_crs
setup_custom_override_crs


# Activate sample data
if [[ ${SAMPLE_DATA} =~ [Tt][Rr][Uu][Ee] ]]; then
  cp -r "${CATALINA_HOME}"/data/* "${GEOSERVER_DATA_DIR}"
fi


# Recreate DISK QUOTA config, useful to change between H2 and jdbc and change connection or schema
if [[ "${RECREATE_DISKQUOTA}" =~ [Tt][Rr][Uu][Ee] ]]; then
  if [[ -f "${GEOWEBCACHE_CACHE_DIR}"/geowebcache-diskquota.xml ]]; then
    rm "${GEOWEBCACHE_CACHE_DIR}"/geowebcache-diskquota.xml
  fi
  if [[ -f "${GEOWEBCACHE_CACHE_DIR}"/geowebcache-diskquota-jdbc.xml ]]; then
    rm "${GEOWEBCACHE_CACHE_DIR}"/geowebcache-diskquota-jdbc.xml
  fi
fi

export DISK_QUOTA_FREQUENCY DISK_QUOTA_SIZE
if [[  ${DB_BACKEND} =~ [Pp][Oo][Ss][Tt][Gg][Rr][Ee][Ss] ]]; then
  postgres_ssl_setup
  export DISK_QUOTA_BACKEND=JDBC
  export SSL_PARAMETERS=${PARAMS}
  export POSTGRES_SCHEMA=${POSTGRES_SCHEMA}
  default_disk_quota_config
  jdbc_disk_quota_config

  echo -e "[Entrypoint] Checking PostgreSQL connection to see if diskquota tables are loaded: \033[0m"
  if [[  ${POSTGRES_SCHEMA} != 'public' ]]; then
    PGPASSWORD="${POSTGRES_PASS}"
    export PGPASSWORD
    postgres_ready_status "${HOST}" "${POSTGRES_PORT}" "${POSTGRES_USER}" "$POSTGRES_DB"
    create_gwc_tile_tables "${HOST}" "${POSTGRES_PORT}" "${POSTGRES_USER}" "$POSTGRES_DB" "$POSTGRES_SCHEMA"
  fi
else
  export DISK_QUOTA_BACKEND=HSQL
  default_disk_quota_config
fi

# GWC Global Config options GeoServer WMS
export WMS_DIR_INTEGRATION REQUIRE_TILED_PARAMETER WMSC_ENABLED TMS_ENABLED SECURITY_ENABLED
activate_gwc_global_configs

# Default installed extensions
DEFAULT_EXTENSIONS=''
for plugin in $(cat ${REQUIRED_PLUGINS_DIR}/required_plugins.txt); do
  if [ -z "$DEFAULT_EXTENSIONS" ]; then
    DEFAULT_EXTENSIONS=${plugin}
  else
    DEFAULT_EXTENSIONS=${DEFAULT_EXTENSIONS},${plugin}
  fi
done

if [[ -z ${ACTIVE_EXTENSIONS} ]];then
  ACTIVE_EXTENSIONS=${DEFAULT_EXTENSIONS},${STABLE_EXTENSIONS}
fi

# If FORCE_DOWNLOAD_STABLE_EXTENSIONS is true, remove all stable extensions
if [[ ${FORCE_DOWNLOAD_STABLE_EXTENSIONS} =~ [Tt][Rr][Uu][Ee] ]]; then
  rm -rf ${STABLE_PLUGINS_DIR}/*.zip
  rm -rf ${REQUIRED_PLUGINS_DIR}/*.zip
fi

if [[ "$ACTIVE_EXTENSIONS" != "$DEFAULT_EXTENSIONS" ]]; then

  for ext in $(echo "${ACTIVE_EXTENSIONS}" | tr ',' ' '); do
    if echo "${DEFAULT_EXTENSIONS}" | grep -w "${ext}" >/dev/null; then
      if [[ ! -f ${REQUIRED_PLUGINS_DIR}/${ext}.zip ]]; then
        approved_plugins_url="${STABLE_PLUGIN_BASE_URL}/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-${ext}.zip"
        download_extension "${approved_plugins_url}" "${ext}" ${REQUIRED_PLUGINS_DIR}/
      fi
      install_plugin ${REQUIRED_PLUGINS_DIR}/ "${ext}"
    else
      if [[ ! -f ${STABLE_PLUGINS_DIR}/${ext}.zip ]]; then
        # Download the stable extension
        approved_plugins_url="${STABLE_PLUGIN_BASE_URL}/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-${ext}.zip"
        download_extension "${approved_plugins_url}" "${ext}" ${STABLE_PLUGINS_DIR}/
      fi
      # Install the stable extension
      install_plugin ${STABLE_PLUGINS_DIR}/ "${ext}"
    fi
  done
else
  # Install default plugins
  for ext in $(echo "${DEFAULT_EXTENSIONS}" | tr ',' ' '); do
    if [[ ! -f ${REQUIRED_PLUGINS_DIR}/${ext}.zip ]]; then
        approved_plugins_url="${STABLE_PLUGIN_BASE_URL}/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-${ext}.zip"
        download_extension "${approved_plugins_url}" "${ext}" ${REQUIRED_PLUGINS_DIR}/
    fi
    install_plugin ${REQUIRED_PLUGINS_DIR}/ "${ext}"
  done
fi



# Function to install community extensions
export S3_SERVER_URL S3_USERNAME S3_PASSWORD S3_ALIAS
# Pass an additional startup argument i.e -Ds3.properties.location=${GEOSERVER_DATA_DIR}/s3.properties
if [[ -z "${S3_SERVER_URL}" || -z "${S3_USERNAME}" || -z "${S3_PASSWORD}" || -z "${S3_ALIAS}" ]]; then
  echo -e "\e[32m -------------------------------------------------------------------------------- \033[0m"
  echo -e "\e[32m [Entrypoint] One or more variables needed for S3 community extensions are empty, skipping configuration of:\033[0m \e[1;31m s3.properties \033[0m"

else
  if [[ "${ADDITIONAL_JAVA_STARTUP_OPTIONS}" == *"-Ds3.properties.location"* ]]; then
    s3_config
else
    echo -e "\e[32m -------------------------------------------------------------------------------- \033[0m"
    echo -e "\e[32m [Entrypoint] -Ds3.properties.location is not setup in:\033[0m \e[1;31m ${ADDITIONAL_JAVA_STARTUP_OPTIONS} \033[0m"
fi


fi

export JDBC_CONFIG_ENABLED JDBC_IGNORE_PATHS JDBC_STORE_ENABLED POSTGRES_JNDI
# Install community modules plugins
if [[ ! -z ${COMMUNITY_EXTENSIONS} ]]; then
  if  [[ ${FORCE_DOWNLOAD_COMMUNITY_EXTENSIONS} =~ [Tt][Rr][Uu][Ee] ]];then
    rm -rf /community_plugins/*.zip
  fi

  for ext in $(echo "${COMMUNITY_EXTENSIONS}" | tr ',' ' '); do
      if [[ ! -f /community_plugins/${ext}.zip ]]; then
        community_plugins_url="https://build.geoserver.org/geoserver/${GS_VERSION:0:5}x/community-latest/geoserver-${GS_VERSION:0:4}-SNAPSHOT-${ext}.zip"
        download_extension "${community_plugins_url}" "${ext}" /community_plugins
        setup_jdbc_db_store
        setup_jdbc_db_config
        setup_hz_cluster
        install_plugin /community_plugins "${ext}"
      else
        setup_jdbc_db_store
        setup_jdbc_db_config
        setup_hz_cluster
        install_plugin /community_plugins "${ext}"
      fi
  done

fi


# Setup clustering
set_vars
export  READONLY CLUSTER_DURABILITY BROKER_URL EMBEDDED_BROKER TOGGLE_MASTER TOGGLE_SLAVE BROKER_URL
export CLUSTER_CONFIG_DIR MONITOR_AUDIT_PATH INSTANCE_STRING
# Cleanup existing monitoring files
if [[ ${CLUSTERING} =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
  if [[ -d "${GEOSERVER_DATA_DIR}"/monitoring ]];then
    if [[ ${RESET_MONITORING_LOGS} =~ [Tt][Rr][Uu][Ee] ]];then
      find "${GEOSERVER_DATA_DIR}"/monitoring -type d -name 'monitor_*' -exec rm -r {} +
    fi
  fi
fi
create_dir "${MONITOR_AUDIT_PATH}"
export MONITORING_AUDIT_ENABLED MONITORING_AUDIT_ROLL_LIMIT MONITORING_STORAGE MONITORING_MODE MONITORING_SYNC MONITORING_BODY_SIZE MONITORING_BBOX_LOG_CRS MONITORING_BBOX_LOG_LEVEL
setup_monitoring


if [[ ${CLUSTERING} =~ [Tt][Rr][Uu][Ee] ]]; then
  ext=jms-cluster-plugin
  if  [[ ${FORCE_DOWNLOAD_COMMUNITY_EXTENSIONS} =~ [Tt][Rr][Uu][Ee] ]];then
    if [[  -f /community_plugins/${ext}.zip ]]; then
      rm -rf /community_plugins/${ext}.zip
    fi
    community_plugins_url="https://build.geoserver.org/geoserver/${GS_VERSION:0:5}x/community-latest/geoserver-${GS_VERSION:0:4}-SNAPSHOT-${ext}.zip"
    download_extension "${community_plugins_url}" ${ext} /community_plugins
  fi
  if [[ ! -f /community_plugins/${ext}.zip ]]; then
      community_plugins_url="https://build.geoserver.org/geoserver/${GS_VERSION:0:5}x/community-latest/geoserver-${GS_VERSION:0:4}-SNAPSHOT-${ext}.zip"
      download_extension "${community_plugins_url}" ${ext} /community_plugins
      install_plugin /community_plugins ${ext}
    else
      install_plugin /community_plugins ${ext}
  fi

  if [[ -z "${EXISTING_DATA_DIR}" ]];then
      if [[ ! -d "${CLUSTER_CONFIG_DIR}" ]];then
          create_dir "${CLUSTER_CONFIG_DIR}"
          if [[ -d "${CLUSTER_CONFIG_DIR}" ]];then
            chown -R "${USER_NAME}":"${GEO_GROUP_NAME}" "${CLUSTER_CONFIG_DIR}"
          fi
      fi
      if [[  ${DB_BACKEND} =~ [Pp][Oo][Ss][Tt][Gg][Rr][Ee][Ss] ]];then
        postgres_ssl_setup
        export SSL_PARAMETERS=${PARAMS}
      fi
      # Setup configs
      broker_xml_config
      cluster_config
      broker_config
  else
    if [[ -z "${CLUSTER_CONFIG_DIR}" ]];then
      echo -e "\e[32m -------------------------------------------------------------------------------- \033[0m"
      echo -e "[Entrypoint] You are using an existing data directory but you haven't set : \e[1;31m $CLUSTER_CONFIG_DIR \033[0m"
      exit 1
    else
      # Variable to count files if found
      count=0

      # Check if cluster.properties exists and increment the count if found
      if find "${CLUSTER_CONFIG_DIR}" -type f -name "cluster.properties" -exec test -f {} \; ; then
         count=$((count + 1))
      fi

      # Check if embedded-broker.properties exists and increment the count if found
      if find "${CLUSTER_CONFIG_DIR}" -type f -name "embedded-broker.properties" -exec test -f {} \; ; then
         count=$((count + 1))
      fi

      # Check if broker.xml exists and increment the count if found
      if find "${CLUSTER_CONFIG_DIR}" -type f -name "broker.xml" -exec test -f {} \; ; then
        count=$((count + 1))
      fi

      # Check if all three files were found
      if [ $count -ne 3 ]; then
          echo "cluster.properties,embedded-broker.properties and broker.xml were not found in ${CLUSTER_CONFIG_DIR} exiting."
          exit 1
      fi
    fi
  fi
  # Download Clustering module, temporary fixes https://github.com/kartoza/docker-geoserver/issues/514
  cp -r /build_data/jdom2-2.0.6.1.jar "${CATALINA_HOME}"/webapps/"${GEOSERVER_CONTEXT_ROOT}"/WEB-INF/lib/

fi

export REQUEST_TIMEOUT PARALLEL_REQUEST GETMAP REQUEST_EXCEL SINGLE_USER GWC_REQUEST WPS_REQUEST USER_WMS_REQUEST THROTTLE_REQUEST_PER_IP
# Setup control flow properties
setup_control_flow

# TODO: If this value is set and a user resets it in the UI, we need to respect that and not reset it again
export GEOSERVER_LOG_PROFILE
geoserver_logging


if [[ ${POSTGRES_JNDI} =~ [Tt][Rr][Uu][Ee] ]];then
  postgres_ssl_setup
  export SSL_PARAMETERS=${PARAMS}
  if [ -z "${POSTGRES_PORT}" ]; then
    POSTGRES_PORT=5432
    export POSTGRES_PORT="${POSTGRES_PORT}"
  fi
  POSTGRES_JAR_COUNT=$(ls -1 ${CATALINA_HOME}/webapps/${GEOSERVER_CONTEXT_ROOT}/WEB-INF/lib/postgresql-* 2>/dev/null | wc -l)
  if [ "$POSTGRES_JAR_COUNT" != 0 ]; then
    rm "${CATALINA_HOME}"/webapps/"${GEOSERVER_CONTEXT_ROOT}"/WEB-INF/lib/postgresql-*
  fi
  cp "${CATALINA_HOME}"/postgres_config/postgresql-* "${CATALINA_HOME}"/lib/
  if [[ -f ${EXTRA_CONFIG_DIR}/context.xml  ]]; then
    envsubst < "${EXTRA_CONFIG_DIR}"/context.xml > "${CATALINA_HOME}"/conf/context.xml
  else
      # default values
    envsubst < /build_data/context.xml > "${CATALINA_HOME}"/conf/context.xml
  fi

else
  cp "${CATALINA_HOME}"/postgres_config/postgresql-* "${CATALINA_HOME}"/webapps/"${GEOSERVER_CONTEXT_ROOT}"/WEB-INF/lib/
fi


if [[ "${TOMCAT_EXTRAS}" =~ [Tt][Rr][Uu][Ee] ]]; then
    unzip -qq "${REQUIRED_PLUGINS_DIR}"/tomcat_apps.zip -d /tmp/
    if [[ -d /tmp/tomcat_apps/webapps.dist ]];then
      cp -r  /tmp/tomcat_apps/webapps.dist/* "${CATALINA_HOME}"/webapps/
    else
      cp -r  /tmp/tomcat_apps/* "${CATALINA_HOME}"/webapps/
    fi
    rm -r /tmp/tomcat_apps
    if [[ ${POSTGRES_JNDI} =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
      if [[ -f ${EXTRA_CONFIG_DIR}/context.xml  ]]; then
        envsubst < "${EXTRA_CONFIG_DIR}"/context.xml > "${CATALINA_HOME}"/webapps/manager/META-INF/context.xml
      else
        cp /build_data/context.xml "${CATALINA_HOME}"/webapps/manager/META-INF/
        sed -i -e '19,36d' "${CATALINA_HOME}"/webapps/manager/META-INF/context.xml
      fi
    fi
    export TOMCAT_USER
    if [[ -z ${TOMCAT_PASSWORD} ]]; then
        generate_random_string 18
        export TOMCAT_PASSWORD=${RAND}
        if [[ ${SHOW_PASSWORD} =~ [Tt][Rr][Uu][Ee] ]];then
          echo -e "[Entrypoint] GENERATED tomcat  PASSWORD: \e[1;31m $TOMCAT_PASSWORD \033[0m"
        fi
        echo "${TOMCAT_PASSWORD}" >"${GEOSERVER_DATA_DIR}"/tomcat_pass.txt
        # Setup tomcat apps manager
        delete_file "${CATALINA_HOME}"/conf/tomcat-users.xml
        tomcat_user_config
        # Unset random generated password
        unset TOMCAT_PASSWORD
        unset RAND
    else
      # Setup tomcat apps manager
       export TOMCAT_PASSWORD=${TOMCAT_PASSWORD}
       tomcat_user_config
    fi
else
    delete_folder "${CATALINA_HOME}"/webapps/ROOT &&
    delete_folder "${CATALINA_HOME}"/webapps/docs &&
    delete_folder "${CATALINA_HOME}"/webapps/examples &&
    delete_folder "${CATALINA_HOME}"/webapps/host-manager &&
    delete_folder "${CATALINA_HOME}"/webapps/manager

    if [[ "${ROOT_WEBAPP_REDIRECT}" =~ [Tt][Rr][Uu][Ee] ]]; then
        mkdir "${CATALINA_HOME}"/webapps/ROOT
        cat /build_data/index.jsp | sed "s@/geoserver/@/${GEOSERVER_CONTEXT_ROOT}/@g" > "${CATALINA_HOME}"/webapps/ROOT/index.jsp
    fi
fi

# Enable SSL
if [[ ${SSL} =~ [Tt][Rr][Uu][Ee] ]]; then
  # ssl env variables
  if [ -z "${JKS_FILE}" ]; then
    JKS_FILE=letsencrypt.jks
  fi

  file_env 'JKS_KEY_PASSWORD'
  if [ -z "${JKS_KEY_PASSWORD}" ]; then
    generate_random_string 22
    JKS_KEY_PASSWORD=${RAND}
    echo "JKS_KEY_PASSWORD" >> /tmp/set_vars.txt
    unset RAND
  fi

  if [ -z "${KEY_ALIAS}" ]; then
    KEY_ALIAS=letsencrypt
  fi

  file_env 'JKS_STORE_PASSWORD'
  if [ -z "${JKS_STORE_PASSWORD}" ]; then
      generate_random_string 23
      JKS_STORE_PASSWORD=${RAND}
      echo "JKS_STORE_PASSWORD" >> /tmp/set_vars.txt
      unset RAND
  fi

  if [ -z "${P12_FILE}" ]; then
      P12_FILE=letsencrypt.p12
  fi

  file_env 'PKCS12_PASSWORD'
  if [ -z "${PKCS12_PASSWORD}" ]; then
     generate_random_string 24
      PKCS12_PASSWORD=${RAND}
      echo "PKCS12_PASSWORD" >> /tmp/set_vars.txt
      unset RAND
  fi


  # convert LetsEncrypt certificates
  # https://community.letsencrypt.org/t/cry-for-help-windows-tomcat-ssl-lets-encrypt/22902/4

  # remove existing key-stores

  rm -f "$P12_FILE"
  rm -f "$JKS_FILE"

  export PKCS12_PASSWORD

  # Copy PFX file if it exists in the extra config directory
  if [ -f "${EXTRA_CONFIG_DIR}"/certificate.pfx ]; then
    cp "${EXTRA_CONFIG_DIR}"/certificate.pfx  "${CERT_DIR}"/certificate.pfx
  fi

  if [[ -f ${CERT_DIR}/certificate.pfx ]]; then
    # Generate private key
    openssl pkcs12 -in "${CERT_DIR}"/certificate.pfx -nocerts \
      -out "${CERT_DIR}"/privkey.pem -nodes -password pass:"$PKCS12_PASSWORD" -passin pass:"$PKCS12_PASSWORD"
    # Generate certificate only
    openssl pkcs12 -in "${CERT_DIR}"/certificate.pfx -clcerts -nodes -nokeys \
      -out "${CERT_DIR}"/fullchain.pem -password pass:"$PKCS12_PASSWORD" -passin pass:"$PKCS12_PASSWORD"
  fi

  # Check if mounted file contains proper keys otherwise use open ssl
  if [[ ! -f ${CERT_DIR}/fullchain.pem ]]; then
    openssl req -x509 -newkey rsa:4096 -keyout "${CERT_DIR}"/privkey.pem -out \
      "${CERT_DIR}"/fullchain.pem -days 3650 -nodes -sha256 -subj '/CN=geoserver'
  fi

  # convert PEM to PKCS12

  openssl pkcs12 -export \
    -in "$CERT_DIR"/fullchain.pem \
    -inkey "$CERT_DIR"/privkey.pem \
    -name "$KEY_ALIAS" \
    -out "${CERT_DIR}"/"$P12_FILE" \
    -password pass:"$PKCS12_PASSWORD"

  # import PKCS12 into JKS
  export JKS_KEY_PASSWORD JKS_STORE_PASSWORD


  keytool -importkeystore \
    -noprompt \
    -trustcacerts \
    -alias "$KEY_ALIAS" \
    -destkeypass "$JKS_KEY_PASSWORD" \
    -destkeystore "${CERT_DIR}"/"$JKS_FILE" \
    -deststorepass "$JKS_STORE_PASSWORD" \
    -srckeystore "${CERT_DIR}"/"$P12_FILE" \
    -srcstorepass "$PKCS12_PASSWORD" \
    -srcstoretype PKCS12

  SSL_CONF=${CATALINA_HOME}/conf/ssl-tomcat.xsl

else
    cp "${CATALINA_HOME}"/conf/ssl-tomcat.xsl "${CATALINA_HOME}"/conf/ssl-tomcat_no_https.xsl
    sed -i -e '95,138d' "${CATALINA_HOME}"/conf/ssl-tomcat_no_https.xsl
    SSL_CONF=${CATALINA_HOME}/conf/ssl-tomcat_no_https.xsl

fi # End SSL settings


# change server configuration

if [ -n "$HTTP_PORT" ]; then
  HTTP_PORT_PARAM="--stringparam http.port $HTTP_PORT "
fi

if [ -n "$HTTP_PROXY_NAME" ]; then
  HTTP_PROXY_NAME_PARAM="--stringparam http.proxyName $HTTP_PROXY_NAME "
fi

if [ -n "$HTTP_PROXY_PORT" ]; then
  HTTP_PROXY_PORT_PARAM="--stringparam http.proxyPort $HTTP_PROXY_PORT "
fi

if [ -n "$HTTP_REDIRECT_PORT" ]; then
  HTTP_REDIRECT_PORT_PARAM="--stringparam http.redirectPort $HTTP_REDIRECT_PORT "
fi

if [ -n "$HTTP_CONNECTION_TIMEOUT" ]; then
  HTTP_CONNECTION_TIMEOUT_PARAM="--stringparam http.connectionTimeout $HTTP_CONNECTION_TIMEOUT "
fi

if [ -n "$HTTP_COMPRESSION" ]; then
  HTTP_COMPRESSION_PARAM="--stringparam http.compression $HTTP_COMPRESSION "
fi

if [ -n "$HTTP_SCHEME" ]; then
  HTTP_SCHEME_PARAM="--stringparam http.scheme $HTTP_SCHEME "
fi

if [ -n "$HTTP_MAX_HEADER_SIZE" ]; then
  HTTP_MAX_HEADER_SIZE_PARAM="--stringparam http.maxHttpHeaderSize $HTTP_MAX_HEADER_SIZE "
fi

if [[ "$HTTP_RELAX_CHARS" =~ [Tt][Rr][Uu][Ee] ]] ; then
  HTTP_RELAX_CHARS_PARAM="--stringparam http.relaxedPathChars {}[]\| "
fi

if [[ "$HTTP_RELAX_QUERY" =~ [Tt][Rr][Uu][Ee] ]] ; then
  HTTP_RELAX_QUERY_PARAM="--stringparam http.relaxedQueryChars {}[]\| "
fi

if [ -n "$HTTPS_SCHEME" ] ; then
    HTTPS_SCHEME_PARAM="--stringparam https.scheme $HTTPS_SCHEME "
fi

if [ -n "$HTTPS_PORT" ]; then
  HTTPS_PORT_PARAM="--stringparam https.port $HTTPS_PORT "
fi

if [ -n "$HTTPS_MAX_THREADS" ]; then
  HTTPS_MAX_THREADS_PARAM="--stringparam https.maxThreads $HTTPS_MAX_THREADS "
fi

if [ -n "$HTTPS_CLIENT_AUTH" ]; then
  HTTPS_CLIENT_AUTH_PARAM="--stringparam https.clientAuth $HTTPS_CLIENT_AUTH "
fi

if [ -n "$HTTPS_PROXY_NAME" ]; then
  HTTPS_PROXY_NAME_PARAM="--stringparam https.proxyName $HTTPS_PROXY_NAME "
fi

if [ -n "$HTTPS_PROXY_PORT" ]; then
  HTTPS_PROXY_PORT_PARAM="--stringparam https.proxyPort $HTTPS_PROXY_PORT "
fi

if [ -n "$HTTPS_COMPRESSION" ]; then
  HTTPS_COMPRESSION_PARAM="--stringparam https.compression $HTTPS_COMPRESSION "
fi

if [ -n "$HTTPS_MAX_HEADER_SIZE" ]; then
  HTTPS_MAX_HEADER_SIZE_PARAM="--stringparam https.maxHttpHeaderSize $HTTPS_MAX_HEADER_SIZE "
fi

if [ -n "$JKS_FILE" ]; then
  JKS_FILE_PARAM="--stringparam https.keystoreFile ${CERT_DIR}/$JKS_FILE "
fi
if [ -n "$JKS_KEY_PASSWORD" ]; then
  JKS_KEY_PASSWORD_PARAM="--stringparam https.keystorePass $JKS_KEY_PASSWORD "
fi

if [ -n "$KEY_ALIAS" ]; then
  KEY_ALIAS_PARAM="--stringparam https.keyAlias $KEY_ALIAS "
fi

if [ -n "$JKS_STORE_PASSWORD" ]; then
  JKS_STORE_PASSWORD_PARAM="--stringparam https.keyPass $JKS_STORE_PASSWORD "
fi

transform="xsltproc \
  --output ${CATALINA_HOME}/conf/server.xml \
  $HTTP_PORT_PARAM \
  $HTTP_PROXY_NAME_PARAM \
  $HTTP_PROXY_PORT_PARAM \
  $HTTP_REDIRECT_PORT_PARAM \
  $HTTP_CONNECTION_TIMEOUT_PARAM \
  $HTTP_COMPRESSION_PARAM \
  $HTTP_SCHEME_PARAM \
  $HTTP_RELAX_CHARS_PARAM \
  $HTTP_RELAX_QUERY_PARAM \
  $HTTP_MAX_HEADER_SIZE_PARAM \
  $HTTPS_SCHEME_PARAM \
  $HTTPS_PORT_PARAM \
  $HTTPS_MAX_THREADS_PARAM \
  $HTTPS_CLIENT_AUTH_PARAM \
  $HTTPS_PROXY_NAME_PARAM \
  $HTTPS_PROXY_PORT_PARAM \
  $HTTPS_COMPRESSION_PARAM \
  $HTTPS_MAX_HEADER_SIZE_PARAM \
  $JKS_FILE_PARAM \
  $JKS_KEY_PASSWORD_PARAM \
  $KEY_ALIAS_PARAM \
  $JKS_STORE_PASSWORD_PARAM \
  ${SSL_CONF} \
  ${CATALINA_HOME}/conf/server.xml"


if [[ -f ${EXTRA_CONFIG_DIR}/server.xml ]]; then
  cp -f "${EXTRA_CONFIG_DIR}"/server.xml "${CATALINA_HOME}"/conf/
else
  # default value
  eval "$transform"
  # Add x-forwarded headers
  if [[ "${ACTIVATE_PROXY_HEADERS}" =~ [Tt][Rr][Uu][Ee] ]]; then
    sed -i.bak -r '/\<\Host\>/ i\ \t<Valve className="org.apache.catalina.valves.RemoteIpValve" remoteIpHeader="x-forwarded-for" remoteIpProxiesHeader="x-forwarded-by" protocolHeader="x-forwarded-proto" protocolHeaderHttpsValue="https"/>' "${CATALINA_HOME}"/conf/server.xml
  fi
fi



# Security hardening of tomcat
sed -i 's/8005/-1/g' "${CATALINA_HOME}"/conf/server.xml

# Cleanup temp file
delete_file "${CATALINA_HOME}"/conf/ssl-tomcat_no_https.xsl

#Unset env variables
if [[ -f /tmp/set_vars.txt ]];then
  for vars in $(cat /tmp/set_vars.txt);do unset $vars;done
  rm /tmp/set_vars.txt
fi


if [[ -z "${EXISTING_DATA_DIR}" ]]; then
  /scripts/update_passwords.sh
fi

# Run some extra bash script to fix issues i.e missing dependencies in lib caused by community extensions
entry_point_script

log4j_logging

