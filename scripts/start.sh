#!/bin/bash

# install Font files in resources/fonts if they exist

if ls ${FONTS_DIR}/*.ttf > /dev/null 2>&1; then \
      cp -rf ${FONTS_DIR}/*.ttf /usr/share/fonts/truetype/; \
	fi;

# Install opentype fonts
if ls ${FONTS_DIR}/*.otf > /dev/null 2>&1; then \
      cp -rf ${FONTS_DIR}/*.otf /usr/share/fonts/opentype/; \
	fi;

if [[ ${SAMPLE_DATA} =~ [Tt][Rr][Uu][Ee] ]]; then \
  echo "Installing default data directory"
  cp -r ${CATALINA_HOME}/data/* ${GEOSERVER_DATA_DIR}
fi

function s3_config() {
  if [[ -f "${GEOSERVER_DATA_DIR}"/s3.properties  ]]; then \
    rm "${GEOSERVER_DATA_DIR}"/s3.properties
  fi;


cat > "${GEOSERVER_DATA_DIR}"/s3.properties <<EOF
alias.s3.endpoint=${S3_SERVER_URL}
alias.s3.user=${S3_USERNAME}
alias.s3.password=${S3_PASSWORD}
EOF

}

function install_plugin() {
  DATA_PATH=/community_plugins
  if [ -n "$1" ]
  then
      DATA_PATH=$1
  fi
  EXT=$2

  unzip ${DATA_PATH}/${EXT}.zip -d /tmp/gs_plugin \
  && mv /tmp/gs_plugin/*.jar "${CATALINA_HOME}"/webapps/geoserver/WEB-INF/lib/ \
  && rm -rf /tmp/gs_plugin

}

# Install stable plugins
 for ext in $(echo "${STABLE_EXTENSIONS}" | tr ',' ' '); do
        echo "Enabling ${ext} for GeoServer ${GS_VERSION}"
        if [[  -z "${STABLE_EXTENSIONS}" ]]; then \
          echo "Do not install any plugins"
        else
            echo "Installing ${ext} plugin"
            install_plugin /plugins ${ext}
        fi
done

# Install community modules plugins
 for ext in $(echo "${COMMUNITY_EXTENSIONS}" | tr ',' ' '); do
        echo "Enabling ${ext} for GeoServer ${GS_VERSION}"
        if [[  -z ${COMMUNITY_EXTENSIONS} ]]; then \
          echo "Do not install any plugins"
        else
            if [[ ${ext} == 's3-geotiff-plugin' ]]; then \
              s3_config
              install_plugin /community_plugins ${ext}
            elif [[ ${ext} != 's3-geotiff-plugin' ]]; then
              echo "Installing ${ext} plugin"
              install_plugin /community_plugins ${ext}

            fi
        fi
done


if [[ -f "${GEOSERVER_DATA_DIR}"/controlflow.properties  ]]; then \
    rm "${GEOSERVER_DATA_DIR}"/controlflow.properties
fi;


cat > "${GEOSERVER_DATA_DIR}"/controlflow.properties <<EOF
timeout=${REQUEST_TIMEOUT}
ows.global=${PARARELL_REQUEST}
ows.wms.getmap=${GETMAP}
ows.wfs.getfeature.application/msexcel=${REQUEST_EXCEL}
user=${SINGLE_USER}
ows.gwc=${GWC_REQUEST}
user.ows.wps.execute=${WPS_REQUEST}
EOF

if [[ "${TOMCAT_EXTRAS}" =~ [Tt][Rr][Uu][Ee] ]]; then \
  unzip tomcat_apps.zip -d /tmp/tomcat && \
  mv /tmp/tomcat/tomcat_apps/* ${CATALINA_HOME}/webapps/ && \
  rm -r /tmp/tomcat && \
  cp /build_data/tomcat-users.xml /usr/local/tomcat/conf && \
  sed -i "s/TOMCAT_PASS/${TOMCAT_PASSWORD}/g" /usr/local/tomcat/conf/tomcat-users.xml
  else
    rm -rf "${CATALINA_HOME}"/webapps/ROOT && \
    rm -rf "${CATALINA_HOME}"/webapps/docs && \
    rm -rf "${CATALINA_HOME}"/webapps/examples && \
    rm -rf "${CATALINA_HOME}"/webapps/host-manager && \
    rm -rf "${CATALINA_HOME}"/webapps/manager; \
  fi;

if [[ ${SSL} =~ [Tt][Rr][Uu][Ee] ]]; then \

  # convert LetsEncrypt certificates
  # https://community.letsencrypt.org/t/cry-for-help-windows-tomcat-ssl-lets-encrypt/22902/4

  # remove existing keystores

  rm -f "$P12_FILE"
  rm -f "$JKS_FILE"

  if [[  -f ${LETSENCRYPT_CERT_DIR}/certificate.pfx ]]; then \
    # Generate private key
      openssl pkcs12 -in ${LETSENCRYPT_CERT_DIR}/certificate.pfx -nocerts \
      -out ${LETSENCRYPT_CERT_DIR}/privkey.pem -nodes -password pass:$PKCS12_PASSWORD -passin pass:$PKCS12_PASSWORD
      # Generate certificate only
      openssl pkcs12 -in ${LETSENCRYPT_CERT_DIR}/certificate.pfx -clcerts -nodes -nokeys \
      -out ${LETSENCRYPT_CERT_DIR}/fullchain.pem -password pass:$PKCS12_PASSWORD -passin pass:$PKCS12_PASSWORD
  fi


  # Check if mounted file contains proper keys otherwise use open ssl
  if [[ ! -f ${LETSENCRYPT_CERT_DIR}/fullchain.pem ]]; then \
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

  if [ -n "$HTTP_PORT" ] ; then
      HTTP_PORT_PARAM="--stringparam http.port $HTTP_PORT "
  fi

  if [ -n "$HTTP_PROXY_NAME" ] ; then
      HTTP_PROXY_NAME_PARAM="--stringparam http.proxyName $HTTP_PROXY_NAME "
  fi

  if [ -n "$HTTP_PROXY_PORT" ] ; then
      HTTP_PROXY_PORT_PARAM="--stringparam http.proxyPort $HTTP_PROXY_PORT "
  fi

  if [ -n "$HTTP_REDIRECT_PORT" ] ; then
      HTTP_REDIRECT_PORT_PARAM="--stringparam http.redirectPort $HTTP_REDIRECT_PORT "
  fi

  if [ -n "$HTTP_CONNECTION_TIMEOUT" ] ; then
      HTTP_CONNECTION_TIMEOUT_PARAM="--stringparam http.connectionTimeout $HTTP_CONNECTION_TIMEOUT "
  fi

  if [ -n "$HTTP_COMPRESSION" ] ; then
      HTTP_COMPRESSION_PARAM="--stringparam http.compression $HTTP_COMPRESSION "
  fi

  if [ -n "$HTTPS_PORT" ] ; then
      HTTPS_PORT_PARAM="--stringparam https.port $HTTPS_PORT "
  fi

  if [ -n "$HTTPS_MAX_THREADS" ] ; then
      HTTPS_MAX_THREADS_PARAM="--stringparam https.maxThreads $HTTPS_MAX_THREADS "
  fi

  if [ -n "$HTTPS_CLIENT_AUTH" ] ; then
      HTTPS_CLIENT_AUTH_PARAM="--stringparam https.clientAuth $HTTPS_CLIENT_AUTH "
  fi

  if [ -n "$HTTPS_PROXY_NAME" ] ; then
      HTTPS_PROXY_NAME_PARAM="--stringparam https.proxyName $HTTPS_PROXY_NAME "
  fi

  if [ -n "$HTTPS_PROXY_PORT" ] ; then
      HTTPS_PROXY_PORT_PARAM="--stringparam https.proxyPort $HTTPS_PROXY_PORT "
  fi

  if [ -n "$HTTPS_COMPRESSION" ] ; then
      HTTPS_COMPRESSION_PARAM="--stringparam https.compression $HTTPS_COMPRESSION "
  fi

  if [ -n "$JKS_FILE" ] ; then
      JKS_FILE_PARAM="--stringparam https.keystoreFile ${LETSENCRYPT_CERT_DIR}/$JKS_FILE "
  fi
  if [ -n "$JKS_KEY_PASSWORD" ] ; then
      JKS_KEY_PASSWORD_PARAM="--stringparam https.keystorePass $JKS_KEY_PASSWORD "
  fi

  if [ -n "$KEY_ALIAS" ] ; then
      KEY_ALIAS_PARAM="--stringparam https.keyAlias $KEY_ALIAS "
  fi

  if [ -n "$JKS_STORE_PASSWORD" ] ; then
      JKS_STORE_PASSWORD_PARAM="--stringparam https.keyPass $JKS_STORE_PASSWORD "
  fi

  transform="xsltproc \
    --output conf/server.xml \
    $HTTP_PORT_PARAM \
    $HTTP_PROXY_NAME_PARAM \
    $HTTP_PROXY_PORT_PARAM \
    $HTTP_REDIRECT_PORT_PARAM \
    $HTTP_CONNECTION_TIMEOUT_PARAM \
    $HTTP_COMPRESSION_PARAM \
    $HTTPS_PORT_PARAM \
    $HTTPS_MAX_THREADS_PARAM \
    $HTTPS_CLIENT_AUTH_PARAM \
    $HTTPS_PROXY_NAME_PARAM \
    $HTTPS_PROXY_PORT_PARAM \
    $HTTPS_COMPRESSION_PARAM \
    $JKS_FILE_PARAM \
    $JKS_KEY_PASSWORD_PARAM \
    $KEY_ALIAS_PARAM \
    $JKS_STORE_PASSWORD_PARAM \
    conf/letsencrypt-tomcat.xsl \
    conf/server.xml"

  eval "$transform"

fi;

if [[ -z "${EXISTING_DATA_DIR}" ]]; then \
    /scripts/update_passwords.sh
fi;
