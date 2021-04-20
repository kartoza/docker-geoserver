#!/bin/bash

source /scripts/env-data.sh
source /scripts/functions.sh
GS_VERSION=$(cat /scripts/geoserver_version.txt)
MONITOR_AUDIT_PATH="${GEOSERVER_DATA_DIR}/monitoring/monitor_$RANDOMSTRING"

# Set install directory based on geoserver version
if [[ -f /geoserver/start.jar ]]; then
   GEOSERVER_INSTALL_DIR=${GEOSERVER_HOME}
else
  GEOSERVER_INSTALL_DIR=${CATALINA_HOME}
fi


# Useful for development - We need a clean state of data directory
if [[ "${RECREATE_DATADIR}" =~ [Tt][Rr][Uu][Ee] ]]; then
  rm -rf ${GEOSERVER_DATA_DIR}/*
fi

# install Font files in resources/fonts if they exists
if ls ${FONTS_DIR}/*.ttf >/dev/null 2>&1; then
  cp -rf ${FONTS_DIR}/*.ttf /usr/share/fonts/truetype/
fi

# Install opentype fonts
if ls ${FONTS_DIR}/*.otf >/dev/null 2>&1; then
  cp -rf ${FONTS_DIR}/*.otf /usr/share/fonts/opentype/
fi

if [[ ! -d ${GEOSERVER_DATA_DIR}/user_projections ]]; then
  echo "Adding custom projection directory"
  cp -r ${CATALINA_HOME}/data/user_projections ${GEOSERVER_DATA_DIR}
fi

if [[ ${SAMPLE_DATA} =~ [Tt][Rr][Uu][Ee] ]]; then
  echo "Activating default data directory"
  cp -r ${CATALINA_HOME}/data/* ${GEOSERVER_DATA_DIR}
fi



if [[  ${DB_BACKEND} =~ [Pp][Oo][Ss][Tt][Gg][Rr][Ee][Ss] ]]; then
  disk_quota_config
fi

create_dir ${MONITOR_AUDIT_PATH}

# Install stable plugins
if [[ -z "${STABLE_EXTENSIONS}" ]]; then
  echo "STABLE_EXTENSIONS is unset, so we do not install any stable extensions"
else
  for ext in $(echo "${STABLE_EXTENSIONS}" | tr ',' ' '); do
      echo "Enabling ${ext} for GeoServer ${GS_VERSION}"
      if [[ ! -f /plugins/${ext}.zip ]]; then
        approved_plugins_url="https://liquidtelecom.dl.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-${ext}.zip"
        download_extension ${approved_plugins_url} ${ext} /plugins
        install_plugin /plugins ${ext}
      else
        install_plugin /plugins ${ext}
      fi

  done
fi

# Function to install community extensions
function community_config() {
    if [[ ${ext} == 's3-geotiff-plugin' ]]; then
        s3_config
        echo "Installing ${ext} "
        install_plugin /community_plugins ${ext}
    elif [[ ${ext} != 's3-geotiff-plugin' ]]; then
        echo "Installing ${ext} "
        install_plugin /community_plugins ${ext}
    fi
}

# Install community modules plugins
if [[ -z ${COMMUNITY_EXTENSIONS} ]]; then
  echo "COMMUNITY_EXTENSIONS is unset, so we do not install any community extensions"
else
  for ext in $(echo "${COMMUNITY_EXTENSIONS}" | tr ',' ' '); do
      echo "Enabling ${ext} for GeoServer ${GS_VERSION}"
      if [[ ! -f /community_plugins/${ext}.zip ]]; then
        community_plugins_url="https://build.geoserver.org/geoserver/${GS_VERSION:0:5}x/community-latest/geoserver-${GS_VERSION:0:4}-SNAPSHOT-${ext}.zip"
        download_extension ${community_plugins_url} ${ext} /community_plugins
        community_config
      else
        community_config
      fi
  done
fi

# Setup clustering
if [[ ${CLUSTERING} =~ [Tt][Rr][Uu][Ee] ]]; then
  CLUSTER_CONFIG_DIR="${GEOSERVER_DATA_DIR}/cluster/instance_$RANDOMSTRING"
  CLUSTER_LOCKFILE="${CLUSTER_CONFIG_DIR}/.cluster.lock"
  if [[ ! -f $CLUSTER_LOCKFILE ]]; then
      create_dir ${CLUSTER_CONFIG_DIR}
      cp /build_data/broker.xml ${CLUSTER_CONFIG_DIR}
      ext=jms-cluster-plugin
      if [[ ! -f /community_plugins/${ext}.zip ]]; then
        community_plugins_url="https://build.geoserver.org/geoserver/${GS_VERSION:0:5}x/community-latest/geoserver-${GS_VERSION:0:4}-SNAPSHOT-${ext}.zip"
        download_extension ${community_plugins_url} ${ext} /community_plugins
        community_config
      else
        community_config
      fi
      touch ${CLUSTER_LOCKFILE}
  fi
  cluster_config
  broker_config

fi

# Setup control flow properties
setup_control_flow

# Setup tomcat apps manager
if [[ "${TOMCAT_EXTRAS}" =~ [Tt][Rr][Uu][Ee] ]]; then
    unzip -qq /tomcat_apps.zip -d /tmp/tomcat &&
    cp -r  /tmp/tomcat/tomcat_apps/webapps.dist/* ${CATALINA_HOME}/webapps/ &&
    rm -r /tmp/tomcat &&
    cp /build_data/context.xml ${CATALINA_HOME}/webapps/manager/META-INF &&
    tomcat_user_config

else
    rm -rf "${CATALINA_HOME}"/webapps/ROOT &&
    rm -rf "${CATALINA_HOME}"/webapps/docs &&
    rm -rf "${CATALINA_HOME}"/webapps/examples &&
    rm -rf "${CATALINA_HOME}"/webapps/host-manager &&
    rm -rf "${CATALINA_HOME}"/webapps/manager
fi

if [[ ${SSL} =~ [Tt][Rr][Uu][Ee] ]]; then

  # convert LetsEncrypt certificates
  # https://community.letsencrypt.org/t/cry-for-help-windows-tomcat-ssl-lets-encrypt/22902/4

  # remove existing keystores

  rm -f "$P12_FILE"
  rm -f "$JKS_FILE"

  if [[ -f ${LETSENCRYPT_CERT_DIR}/certificate.pfx ]]; then
    # Generate private key
    openssl pkcs12 -in ${LETSENCRYPT_CERT_DIR}/certificate.pfx -nocerts \
      -out ${LETSENCRYPT_CERT_DIR}/privkey.pem -nodes -password pass:$PKCS12_PASSWORD -passin pass:$PKCS12_PASSWORD
    # Generate certificate only
    openssl pkcs12 -in ${LETSENCRYPT_CERT_DIR}/certificate.pfx -clcerts -nodes -nokeys \
      -out ${LETSENCRYPT_CERT_DIR}/fullchain.pem -password pass:$PKCS12_PASSWORD -passin pass:$PKCS12_PASSWORD
  fi

  # Check if mounted file contains proper keys otherwise use open ssl
  if [[ ! -f ${LETSENCRYPT_CERT_DIR}/fullchain.pem ]]; then
    openssl req -x509 -newkey rsa:4096 -keyout ${LETSENCRYPT_CERT_DIR}/privkey.pem -out \
      ${LETSENCRYPT_CERT_DIR}/fullchain.pem -days 3650 -nodes -sha256 -subj '/CN=geoserver'
  fi

  # convert PEM to PKCS12

  openssl pkcs12 -export \
    -in "$LETSENCRYPT_CERT_DIR"/fullchain.pem \
    -inkey "$LETSENCRYPT_CERT_DIR"/privkey.pem \
    -name "$KEY_ALIAS" \
    -out ${LETSENCRYPT_CERT_DIR}/"$P12_FILE" \
    -password pass:"$PKCS12_PASSWORD"

  # import PKCS12 into JKS

  keytool -importkeystore \
    -noprompt \
    -trustcacerts \
    -alias "$KEY_ALIAS" \
    -destkeypass "$JKS_KEY_PASSWORD" \
    -destkeystore ${LETSENCRYPT_CERT_DIR}/"$JKS_FILE" \
    -deststorepass "$JKS_STORE_PASSWORD" \
    -srckeystore ${LETSENCRYPT_CERT_DIR}/"$P12_FILE" \
    -srcstorepass "$PKCS12_PASSWORD" \
    -srcstoretype PKCS12

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

  if [ -n "$HTTP_MAX_HEADER_SIZE" ]; then
    HTTP_MAX_HEADER_SIZE_PARAM="--stringparam http.maxHttpHeaderSize $HTTP_MAX_HEADER_SIZE "
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
    JKS_FILE_PARAM="--stringparam https.keystoreFile ${LETSENCRYPT_CERT_DIR}/$JKS_FILE "
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
    $HTTP_MAX_HEADER_SIZE_PARAM \
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
    ${CATALINA_HOME}/conf/letsencrypt-tomcat.xsl \
    ${CATALINA_HOME}/conf/server.xml"

  eval "$transform"

fi

if [[ -z "${EXISTING_DATA_DIR}" ]]; then
  /scripts/update_passwords.sh
fi
