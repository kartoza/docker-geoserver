#!/bin/bash

source /scripts/functions.sh
source /scripts/env-data.sh
GS_VERSION=$(cat /scripts/geoserver_version.txt)

web_cors

# Useful for development - We need a clean state of data directory
if [[ "${RECREATE_DATADIR}" =~ [Tt][Rr][Uu][Ee] ]]; then
  rm -rf "${GEOSERVER_DATA_DIR}"/*
fi

# install Font files in resources/fonts if they exists
if ls "${FONTS_DIR}"/*.ttf >/dev/null 2>&1; then
  cp -rf "${FONTS_DIR}"/*.ttf /usr/share/fonts/truetype/
fi

# Install opentype fonts
if ls "${FONTS_DIR}"/*.otf >/dev/null 2>&1; then
  cp -rf "${FONTS_DIR}"/*.otf /usr/share/fonts/opentype/
fi

# Add custom espg properties file or the default one
create_dir "${GEOSERVER_DATA_DIR}"/user_projections
create_dir "${GEOWEBCACHE_CACHE_DIR}"

setup_custom_crs

create_dir "${GEOSERVER_DATA_DIR}"/logs
export GEOSERVER_LOG_LEVEL
geoserver_logging

# Activate sample data
if [[ ${SAMPLE_DATA} =~ [Tt][Rr][Uu][Ee] ]]; then
  echo "Activating default data directory"
  cp -r "${CATALINA_HOME}"/data/* "${GEOSERVER_DATA_DIR}"
fi



export DISK_QUOTA_SIZE
if [[  ${DB_BACKEND} =~ [Pp][Oo][Ss][Tt][Gg][Rr][Ee][Ss] ]]; then
  postgres_ssl_setup
  export DISK_QUOTA_BACKEND=JDBC
  export SSL_PARAMETERS=${PARAMS}
  default_disk_quota_config
  jdbc_disk_quota_config
else
  export DISK_QUOTA_BACKEND=H2
  default_disk_quota_config

fi



# Install stable plugins
if [[ -z "${STABLE_EXTENSIONS}" ]]; then
  echo -e "\e[32m STABLE_EXTENSIONS is unset, so we do not install any stable extensions \033[0m"
else
  if  [[ ${FORCE_DOWNLOAD_STABLE_EXTENSIONS} =~ [Tt][Rr][Uu][Ee] ]];then
      rm -rf /stable_plugins/*.zip
      for plugin in $(cat /stable_plugins/stable_plugins.txt); do
        approved_plugins_url="${STABLE_PLUGIN_BASE_URL}/project/geoserver/GeoServer/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-${plugin}.zip"
        download_extension "${approved_plugins_url}" "${plugin}" /stable_plugins
      done
      for ext in $(echo "${STABLE_EXTENSIONS}" | tr ',' ' '); do
        echo "Enabling ${ext} for GeoServer ${GS_VERSION}"
        install_plugin /stable_plugins/ "${ext}"
    done
  else
    for ext in $(echo "${STABLE_EXTENSIONS}" | tr ',' ' '); do
        echo "Enabling ${ext} for GeoServer ${GS_VERSION}"
        if [[ ! -f /stable_plugins/${ext}.zip ]]; then
          approved_plugins_url="https://liquidtelecom.dl.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-${ext}.zip"
          download_extension "${approved_plugins_url}" "${ext}" /stable_plugins/
          install_plugin /stable_plugins/ "${ext}"
        else
          install_plugin /stable_plugins/ "${ext}"
        fi

    done
  fi
fi

if [[ ${ACTIVATE_ALL_STABLE_EXTENSIONS} =~ [Tt][Rr][Uu][Ee] ]];then
  pushd /stable_plugins/ || exit
  for val in *.zip; do
      ext=${val%.*}
      echo "Enabling ${ext} for GeoServer ${GS_VERSION}"
      install_plugin /stable_plugins/ "${ext}"
  done
  pushd "${GEOSERVER_HOME}" || exit
fi


# Function to install community extensions
export S3_SERVER_URL S3_USERNAME S3_PASSWORD

function community_config() {
     echo -e "\e[32m  Installing ${ext} \033[0m"
    install_plugin /community_plugins "${ext}"
}

# Install community modules plugins
if [[ -z ${COMMUNITY_EXTENSIONS} ]]; then
  echo -e "\e[32m COMMUNITY_EXTENSIONS is unset, so we do not install any community extensions \033[0m"
else
  if  [[ ${FORCE_DOWNLOAD_COMMUNITY_EXTENSIONS} =~ [Tt][Rr][Uu][Ee] ]];then
    rm -rf /community_plugins/*.zip
    for plugin in $(cat /community_plugins/community_plugins.txt); do
      community_plugins_url="https://build.geoserver.org/geoserver/${GS_VERSION:0:5}x/community-latest/geoserver-${GS_VERSION:0:4}-SNAPSHOT-${plugin}.zip"
      download_extension "${community_plugins_url}" "${plugin}" /community_plugins
    done
    for ext in $(echo "${COMMUNITY_EXTENSIONS}" | tr ',' ' '); do
        echo "Enabling ${ext} for GeoServer ${GS_VERSION}"
        community_config
    done
  else
    for ext in $(echo "${COMMUNITY_EXTENSIONS}" | tr ',' ' '); do
        echo "Enabling ${ext} for GeoServer ${GS_VERSION}"
        if [[ ! -f /community_plugins/${ext}.zip ]]; then
          community_plugins_url="https://build.geoserver.org/geoserver/${GS_VERSION:0:5}x/community-latest/geoserver-${GS_VERSION:0:4}-SNAPSHOT-${ext}.zip"
          download_extension "${community_plugins_url}" "${ext}" /community_plugins
          community_config
        else
          community_config
        fi
    done
  fi
fi


if [[ ${ACTIVATE_ALL_COMMUNITY_EXTENSIONS} =~ [Tt][Rr][Uu][Ee] ]];then
   pushd /community_plugins/ || exit
    for val in *.zip; do
        ext=${val%.*}
        echo -e "\e[32m  Enabling ${ext} for GeoServer ${GS_VERSION} \033[0m"
        community_config
    done
    pushd "${GEOSERVER_HOME}" || exit
fi

# Setup clustering
set_vars
export  READONLY CLUSTER_DURABILITY BROKER_URL EMBEDDED_BROKER TOGGLE_MASTER TOGGLE_SLAVE BROKER_URL
export CLUSTER_CONFIG_DIR MONITOR_AUDIT_PATH CLUSTER_LOCKFILE INSTANCE_STRING
create_dir "${MONITOR_AUDIT_PATH}"

if [[ ${CLUSTERING} =~ [Tt][Rr][Uu][Ee] ]]; then
  ext=jms-cluster-plugin
  if [[ ! -f /community_plugins/${ext}.zip ]]; then
    community_plugins_url="https://build.geoserver.org/geoserver/${GS_VERSION:0:5}x/community-latest/geoserver-${GS_VERSION:0:4}-SNAPSHOT-${ext}.zip"
    download_extension "${community_plugins_url}" ${ext} /community_plugins
    install_plugin /community_plugins ${ext}
  else
    install_plugin /community_plugins ${ext}
  fi
  if [[ ! -f $CLUSTER_LOCKFILE ]]; then
      if [[ -z "${EXISTING_DATA_DIR}" ]]; then
          create_dir "${CLUSTER_CONFIG_DIR}"
      fi

      if [[  ${DB_BACKEND} =~ [Pp][Oo][Ss][Tt][Gg][Rr][Ee][Ss] ]];then
        postgres_ssl_setup
        export SSL_PARAMETERS=${PARAMS}
      fi
      broker_xml_config
      touch "${CLUSTER_LOCKFILE}"
  fi
  # setup clustering if it's not already defined in an existing data directory
  if [[ -z "${EXISTING_DATA_DIR}" ]]; then
      cluster_config
      broker_config
  fi


fi

export REQUEST_TIMEOUT PARALLEL_REQUEST GETMAP REQUEST_EXCEL SINGLE_USER GWC_REQUEST WPS_REQUEST
# Setup control flow properties
setup_control_flow


if [[ ${POSTGRES_JNDI} =~ [Tt][Rr][Uu][Ee] ]];then
  postgres_ssl_setup
  export SSL_PARAMETERS=${PARAMS}
  if [ -z "${POSTGRES_PORT}" ]; then
    POSTGRES_PORT=5432
    export POSTGRES_PORT="${POSTGRES_PORT}"
  fi
  POSTGRES_JAR_COUNT=$(ls -1 ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/postgresql-* 2>/dev/null | wc -l)
  if [ "$POSTGRES_JAR_COUNT" != 0 ]; then
    rm "${CATALINA_HOME}"/webapps/geoserver/WEB-INF/lib/postgresql-*
  fi
  cp "${CATALINA_HOME}"/postgres_config/postgresql-* "${CATALINA_HOME}"/lib/ &&
  envsubst < /build_data/context.xml > "${CATALINA_HOME}"/conf/context.xml
else
  cp "${CATALINA_HOME}"/postgres_config/postgresql-* "${CATALINA_HOME}"/webapps/geoserver/WEB-INF/lib/
fi


if [[ "${TOMCAT_EXTRAS}" =~ [Tt][Rr][Uu][Ee] ]]; then
    unzip -qq /tomcat_apps.zip -d /tmp/ &&
    cp -r  /tmp/tomcat_apps/webapps.dist/* "${CATALINA_HOME}"/webapps/ &&
    rm -r /tmp/tomcat_apps
    if [[ ${POSTGRES_JNDI} =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
      cp /build_data/context.xml "${CATALINA_HOME}"/webapps/manager/META-INF/
      sed -i -e '19,36d' "${CATALINA_HOME}"/webapps/manager/META-INF/context.xml
    fi
    if [[ -z ${TOMCAT_PASSWORD} ]]; then
        generate_random_string 18
        export TOMCAT_PASSWORD=${RAND}
        echo -e "[Entrypoint] GENERATED tomcat  PASSWORD: \e[1;31m $TOMCAT_PASSWORD \033[0m"
    else
       export TOMCAT_PASSWORD
    fi
    # Setup tomcat apps manager
    export TOMCAT_USER
    tomcat_user_config
else
    delete_folder "${CATALINA_HOME}"/webapps/ROOT &&
    delete_folder "${CATALINA_HOME}"/webapps/docs &&
    delete_folder "${CATALINA_HOME}"/webapps/examples &&
    delete_folder "${CATALINA_HOME}"/webapps/host-manager &&
    delete_folder "${CATALINA_HOME}"/webapps/manager

    if [[ "${ROOT_WEBAPP_REDIRECT}" =~ [Tt][Rr][Uu][Ee] ]]; then
        mkdir "${CATALINA_HOME}"/webapps/ROOT
        cp /build_data/index.jsp "${CATALINA_HOME}"/webapps/ROOT/index.jsp
    fi
fi

# Enable SSL
if [[ ${SSL} =~ [Tt][Rr][Uu][Ee] ]]; then

  # convert LetsEncrypt certificates
  # https://community.letsencrypt.org/t/cry-for-help-windows-tomcat-ssl-lets-encrypt/22902/4

  # remove existing keystores

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
    sed -i -e '83,126d' "${CATALINA_HOME}"/conf/ssl-tomcat_no_https.xsl
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
fi


# Cleanup temp file
delete_file ${CATALINA_HOME}/conf/ssl-tomcat_no_https.xsl


if [[ -z "${EXISTING_DATA_DIR}" ]]; then
  /scripts/update_passwords.sh
fi

setup_logging

