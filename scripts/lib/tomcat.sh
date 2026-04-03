#!/usr/bin/env bash

############################################
# 1. TOMCAT CORE CONFIGURATION
############################################

# Configure Tomcat users (manager / admin)
tomcat_user_config() {
  [[ -f "${CATALINA_HOME}/conf/tomcat-users.xml" ]] && return

  if [[ -f "${EXTRA_CONFIG_DIR}/tomcat-users.xml" ]]; then
    envsubst < "${EXTRA_CONFIG_DIR}/tomcat-users.xml" \
      > "${CATALINA_HOME}/conf/tomcat-users.xml"
  else
    envsubst < /build_data/tomcat-users.xml \
      > "${CATALINA_HOME}/conf/tomcat-users.xml"
  fi
}

# Configure Tomcat JUL logging
tomcat_logging() {
  if [[ -f "${EXTRA_CONFIG_DIR}/logging.properties" ]]; then
    envsubst < "${EXTRA_CONFIG_DIR}/logging.properties" > "${CATALINA_HOME}/conf/logging.properties"
  else
    envsubst < /build_data/logging.properties > "${CATALINA_HOME}/conf/logging.properties"
  fi
}

setup_logging() {
  if [[ ${LOGGING_STDOUT} =~ [Tt][Rr][Uu][Ee] ]]; then
    export CONSOLE_HANDLER_LEVEL
    tomcat_logging
  fi
}
############################################
# 2. GEOSERVER LOGGING
############################################

setup_geoserver_logging(){
  export GEOSERVER_LOG_PROFILE
  geoserver_logging

}

############################################
# 3. JNDI / DATABASE CONFIGURATION
############################################

setup_jndi_status() {
  if [[ ${POSTGRES_JNDI} =~ [Tt][Rr][Uu][Ee] ]]; then
    postgres_ssl_setup
    export SSL_PARAMETERS=${PARAMS}

    : "${POSTGRES_PORT:=5432}"
    export POSTGRES_PORT

    # Remove PostgreSQL jars from GeoServer WEB-INF
    POSTGRES_JAR_COUNT=$(ls -1 ${CATALINA_HOME}/webapps/${GEOSERVER_CONTEXT_ROOT}/WEB-INF/lib/postgresql-* 2>/dev/null | wc -l)
    if [ "$POSTGRES_JAR_COUNT" != 0 ]; then
      rm "${CATALINA_HOME}"/webapps/"${GEOSERVER_CONTEXT_ROOT}"/WEB-INF/lib/postgresql-*
    fi

    # Install JDBC driver into Tomcat
    cp "${CATALINA_HOME}/postgres_config/postgresql-"* \
       "${CATALINA_HOME}/lib/"

    if [[ -f "${EXTRA_CONFIG_DIR}/context.xml" ]]; then
      envsubst < "${EXTRA_CONFIG_DIR}/context.xml" \
        > "${CATALINA_HOME}/conf/context.xml"
    else
      envsubst < /build_data/context.xml \
        > "${CATALINA_HOME}/conf/context.xml"
    fi
  else
    # Fallback: bundle JDBC with GeoServer
    cp "${CATALINA_HOME}/postgres_config/postgresql-"* \
       "${CATALINA_HOME}/webapps/${GEOSERVER_CONTEXT_ROOT}/WEB-INF/lib/"
  fi
}

############################################
# 4. TOMCAT WEBAPPS & MANAGER
############################################

setup_tomcat_webapp_status() {
  if [[ "${TOMCAT_EXTRAS}" =~ [Tt][Rr][Uu][Ee] ]]; then
    unzip -qq "${REQUIRED_PLUGINS_DIR}/tomcat_apps.zip" -d /tmp/

    cp -r /tmp/tomcat_apps/* "${CATALINA_HOME}/webapps/"
    rm -rf /tmp/tomcat_apps

    # Manager context.xml when JNDI disabled
    if [[ ${POSTGRES_JNDI} =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
      if [[ -f "${EXTRA_CONFIG_DIR}/context.xml" ]]; then
        envsubst < "${EXTRA_CONFIG_DIR}/context.xml" \
          > "${CATALINA_HOME}/webapps/manager/META-INF/context.xml"
      else
        cp /build_data/context.xml \
           "${CATALINA_HOME}/webapps/manager/META-INF/"
        sed -i '19,36d' \
          "${CATALINA_HOME}/webapps/manager/META-INF/context.xml"
      fi
    fi

    # Setup Tomcat credentials
    export TOMCAT_USER
    if [[ -z ${TOMCAT_PASSWORD} ]]; then
      generate_random_string 18
      TOMCAT_PASSWORD=${RAND}
      echo "${TOMCAT_PASSWORD}" > "${GEOSERVER_DATA_DIR}/tomcat_pass.txt"
      delete_file "${CATALINA_HOME}/conf/tomcat-users.xml"
      tomcat_user_config
      unset TOMCAT_PASSWORD RAND
    else
      tomcat_user_config
    fi
  else
    # Harden Tomcat: remove default apps
    delete_folder "${CATALINA_HOME}/webapps/ROOT"
    delete_folder "${CATALINA_HOME}/webapps/docs"
    delete_folder "${CATALINA_HOME}/webapps/examples"
    delete_folder "${CATALINA_HOME}/webapps/host-manager"
    delete_folder "${CATALINA_HOME}/webapps/manager"

    if [[ "${ROOT_WEBAPP_REDIRECT}" =~ [Tt][Rr][Uu][Ee] ]]; then
      mkdir -p "${CATALINA_HOME}/webapps/ROOT"
      sed "s@/geoserver/@/${GEOSERVER_CONTEXT_ROOT}/@g" \
        /build_data/index.jsp \
        > "${CATALINA_HOME}/webapps/ROOT/index.jsp"
    fi
  fi
}

############################################
# 5. SSL & SERVER.XML
############################################

setup_tomcat_ssl_status() {

  ############################################
  # Temp cleanup helpers
  ############################################
  TMP_FILES=()

  cleanup_temp() {
    for f in "${TMP_FILES[@]}"; do
      [ -f "$f" ] && rm -f "$f"
    done
  }

  trap cleanup_temp EXIT

  ############################################
  # SSL handling
  ############################################
  if [[ "${SSL}" =~ ^([Tt][Rr][Uu][Ee]|1)$ ]]; then

    # Defaults
    JKS_FILE="${JKS_FILE:-letsencrypt.jks}"
    KEY_ALIAS="${KEY_ALIAS:-letsencrypt}"
    P12_FILE="${P12_FILE:-letsencrypt.p12}"

    file_env JKS_KEY_PASSWORD
    if [ -z "${JKS_KEY_PASSWORD}" ]; then
      generate_random_string 22
      JKS_KEY_PASSWORD="$RAND"
      echo "JKS_KEY_PASSWORD" >> /tmp/set_vars.txt
      unset RAND
    fi

    file_env JKS_STORE_PASSWORD
    if [ -z "${JKS_STORE_PASSWORD}" ]; then
      generate_random_string 23
      JKS_STORE_PASSWORD="$RAND"
      echo "JKS_STORE_PASSWORD" >> /tmp/set_vars.txt
      unset RAND
    fi

    file_env PKCS12_PASSWORD
    if [ -z "${PKCS12_PASSWORD}" ]; then
      generate_random_string 24
      PKCS12_PASSWORD="$RAND"
      echo "PKCS12_PASSWORD" >> /tmp/set_vars.txt
      unset RAND
    fi

    export PKCS12_PASSWORD JKS_KEY_PASSWORD JKS_STORE_PASSWORD

    ############################################
    # Prepare cert directory
    ############################################
    mkdir -p "${CERT_DIR}"

    rm -f \
      "${CERT_DIR}/${P12_FILE}" \
      "${CERT_DIR}/${JKS_FILE}" \
      "${CERT_DIR}/privkey.pem" \
      "${CERT_DIR}/fullchain.pem"

    ############################################
    # Optional mounted certificate
    ############################################
    if [ -f "${EXTRA_CONFIG_DIR}/certificate.pfx" ]; then
      cp "${EXTRA_CONFIG_DIR}/certificate.pfx" "${CERT_DIR}/certificate.pfx"
      TMP_FILES+=("${CERT_DIR}/certificate.pfx")
    fi

    ############################################
    # Extract or generate certs
    ############################################
    if [[ -f "${CERT_DIR}/certificate.pfx" ]]; then
      openssl pkcs12 -in "${CERT_DIR}/certificate.pfx" \
        -nocerts -nodes \
        -out "${CERT_DIR}/privkey.pem" \
        -passin pass:"${PKCS12_PASSWORD}"

      openssl pkcs12 -in "${CERT_DIR}/certificate.pfx" \
        -clcerts -nokeys \
        -out "${CERT_DIR}/fullchain.pem" \
        -passin pass:"${PKCS12_PASSWORD}"
    fi

    if [[ ! -f "${CERT_DIR}/fullchain.pem" ]]; then
      openssl req -x509 -newkey rsa:4096 \
        -keyout "${CERT_DIR}/privkey.pem" \
        -out "${CERT_DIR}/fullchain.pem" \
        -days 3650 -nodes -sha256 \
        -subj '/CN=geoserver'
    fi

    ############################################
    # PEM → PKCS12 → JKS
    ############################################
    openssl pkcs12 -export \
      -in "${CERT_DIR}/fullchain.pem" \
      -inkey "${CERT_DIR}/privkey.pem" \
      -name "${KEY_ALIAS}" \
      -out "${CERT_DIR}/${P12_FILE}" \
      -password pass:"${PKCS12_PASSWORD}"

    keytool -importkeystore \
      -noprompt \
      -trustcacerts \
      -alias "${KEY_ALIAS}" \
      -destkeystore "${CERT_DIR}/${JKS_FILE}" \
      -deststorepass "${JKS_STORE_PASSWORD}" \
      -destkeypass "${JKS_KEY_PASSWORD}" \
      -srckeystore "${CERT_DIR}/${P12_FILE}" \
      -srcstoretype PKCS12 \
      -srcstorepass "${PKCS12_PASSWORD}"

    SSL_CONF="${CATALINA_HOME}/conf/ssl-tomcat.xsl"

  ############################################
  # SSL disabled
  ############################################
  else
    SSL_CONF="${CATALINA_HOME}/conf/ssl-tomcat_no_https.xsl"
    cp "${CATALINA_HOME}/conf/ssl-tomcat.xsl" "${SSL_CONF}"
    sed -i '95,138d' "${SSL_CONF}"
    TMP_FILES+=("${SSL_CONF}")
  fi

  ############################################
  # XSLT parameter building (unchanged)
  ############################################
  [ -n "$HTTP_PORT" ] && HTTP_PORT_PARAM="--stringparam http.port $HTTP_PORT "
  [ -n "$HTTP_PROXY_NAME" ] && HTTP_PROXY_NAME_PARAM="--stringparam http.proxyName $HTTP_PROXY_NAME "
  [ -n "$HTTP_PROXY_PORT" ] && HTTP_PROXY_PORT_PARAM="--stringparam http.proxyPort $HTTP_PROXY_PORT "
  [ -n "$HTTP_REDIRECT_PORT" ] && HTTP_REDIRECT_PORT_PARAM="--stringparam http.redirectPort $HTTP_REDIRECT_PORT "
  [ -n "$HTTP_CONNECTION_TIMEOUT" ] && HTTP_CONNECTION_TIMEOUT_PARAM="--stringparam http.connectionTimeout $HTTP_CONNECTION_TIMEOUT "
  [ -n "$HTTP_COMPRESSION" ] && HTTP_COMPRESSION_PARAM="--stringparam http.compression $HTTP_COMPRESSION "
  [ -n "$HTTP_SCHEME" ] && HTTP_SCHEME_PARAM="--stringparam http.scheme $HTTP_SCHEME "
  [ -n "$HTTP_MAX_HEADER_SIZE" ] && HTTP_MAX_HEADER_SIZE_PARAM="--stringparam http.maxHttpHeaderSize $HTTP_MAX_HEADER_SIZE "

  [[ "$HTTP_RELAX_CHARS" =~ ^([Tt][Rr][Uu][Ee]|1)$ ]] && \
    HTTP_RELAX_CHARS_PARAM="--stringparam http.relaxedPathChars {}[]\| "

  [[ "$HTTP_RELAX_QUERY" =~ ^([Tt][Rr][Uu][Ee]|1)$ ]] && \
    HTTP_RELAX_QUERY_PARAM="--stringparam http.relaxedQueryChars {}[]\| "

  [ -n "$HTTPS_PORT" ] && HTTPS_PORT_PARAM="--stringparam https.port $HTTPS_PORT "
  [ -n "$JKS_FILE" ] && JKS_FILE_PARAM="--stringparam https.keystoreFile ${CERT_DIR}/${JKS_FILE} "
  [ -n "$JKS_KEY_PASSWORD" ] && JKS_KEY_PASSWORD_PARAM="--stringparam https.keystorePass $JKS_KEY_PASSWORD "
  [ -n "$KEY_ALIAS" ] && KEY_ALIAS_PARAM="--stringparam https.keyAlias $KEY_ALIAS "
  [ -n "$JKS_STORE_PASSWORD" ] && JKS_STORE_PASSWORD_PARAM="--stringparam https.keyPass $JKS_STORE_PASSWORD "

  ############################################
  # Apply transform
  ############################################
  if [[ -f "${EXTRA_CONFIG_DIR}/server.xml" ]]; then
    cp -f "${EXTRA_CONFIG_DIR}/server.xml" "${CATALINA_HOME}/conf/"
  else
    xsltproc \
      --output "${CATALINA_HOME}/conf/server.xml" \
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
      $HTTPS_PORT_PARAM \
      $JKS_FILE_PARAM \
      $JKS_KEY_PASSWORD_PARAM \
      $KEY_ALIAS_PARAM \
      $JKS_STORE_PASSWORD_PARAM \
      "${SSL_CONF}" \
      "${CATALINA_HOME}/conf/server.xml"

    if [[ "${ACTIVATE_PROXY_HEADERS}" =~ ^([Tt][Rr][Uu][Ee]|1)$ ]]; then
      sed -i -r '/\<\Host\>/ i\ \t<Valve className="org.apache.catalina.valves.RemoteIpValve" remoteIpHeader="x-forwarded-for" protocolHeader="x-forwarded-proto" />' \
        "${CATALINA_HOME}/conf/server.xml"
    fi
  fi

  ############################################
  # Hardening
  ############################################
  sed -i 's/8005/-1/g' "${CATALINA_HOME}/conf/server.xml"
}


############################################
# 6. WEB.XML / CORS
############################################

web_cors() {
  local web_xml="${CATALINA_HOME}/conf/web.xml"
  local custom_web_xml="${EXTRA_CONFIG_DIR}/web.xml"
  if [[ ! -f "${web_xml}" ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f "${custom_web_xml}"  ]]; then
      cp -f "${custom_web_xml}"  "${CATALINA_HOME}"/conf/
    else
      # default values
      envsubst < /build_data/web.xml > "${web_xml}"
      ###
      # Deactivate CORS filter in web.xml if DISABLE_CORS=true
      # Useful if CORS is handled outside of Tomcat (e.g. in a proxying webserver like nginx)
      ###
      if [[ "${DISABLE_CORS}" =~ [Tt][Rr][Uu][Ee] ]]; then
        sed -i 's/<!-- CORS_START.*/<!-- CORS DEACTIVATED BY DISABLE_CORS -->\n<!--/; s/^.*<!-- CORS_END -->/-->/' \
          "${web_xml}"
      fi
      ###
      # Deactivate security filter in web.xml if DISABLE_SECURITY_FILTER=true
      # https://github.com/kartoza/docker-geoserver/issues/549
      ###
      if [[ "${DISABLE_SECURITY_FILTER}" =~ [Tt][Rr][Uu][Ee] ]]; then
        sed -i 's/<!-- SECURITY_START.*/<!-- SECURITY FILTER DEACTIVATED BY DISABLE_SECURITY_FILTER -->\n<!--/; s/^.*<!-- SECURITY_END -->/-->/' \
          "${web_xml}"
      fi
    fi
  fi
}

############################################
# 7. JVM & TELEMETRY
############################################

configure_jvm() {
  if [[ -z ${GEOSERVER_OPTS} ]];then

  export GEOSERVER_OPTS="-Djava.awt.headless=true -server -Xms${INITIAL_MEMORY} -Xmx${MAXIMUM_MEMORY} \
       -XX:PerfDataSamplingInterval=500 -Dorg.geotools.referencing.forceXY=true \
       -XX:SoftRefLRUPolicyMSPerMB=36000   \
       -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=20 -XX:ConcGCThreads=5 \
       -XX:InitiatingHeapOccupancyPercent=${INITIAL_HEAP_OCCUPANCY_PERCENT}  \
       -Djts.overlay=ng \
       -Dfile.encoding=${ENCODING} \
       -Duser.timezone=${TIMEZONE} \
       -Duser.language=${LANGUAGE} \
       -Duser.region=${REGION} \
       -Duser.country=${COUNTRY} \
       -DENABLE_JSONP=${ENABLE_JSONP} \
       -DMAX_FILTER_RULES=${MAX_FILTER_RULES} \
       -DOPTIMIZE_LINE_WIDTH=${OPTIMIZE_LINE_WIDTH} \
       -DALLOW_ENV_PARAMETRIZATION=${ALLOW_ENV_PARAMETRIZATION} \
       -Djavax.servlet.request.encoding=${CHARACTER_ENCODING} \
       -Djavax.servlet.response.encoding=${CHARACTER_ENCODING} \
       -DCLUSTER_CONFIG_DIR=${CLUSTER_CONFIG_DIR} \
       -DGEOSERVER_DATA_DIR=${GEOSERVER_DATA_DIR} \
       -DGEOSERVER_FILEBROWSER_HIDEFS=${GEOSERVER_FILEBROWSER_HIDEFS} \
       -DGEOSERVER_AUDIT_PATH=${MONITOR_AUDIT_PATH} \
       -Dorg.geotools.shapefile.datetime=${USE_DATETIME_IN_SHAPEFILE} \
       -Dorg.geotools.localDateTimeHandling=true \
       -Dsun.java2d.renderer.useThreadLocal=false \
       -Dsun.java2d.renderer.pixelsize=8192 -server -XX:NewSize=300m \
       -Dlog4j.configuration=${CATALINA_HOME}/log4j.properties \
       --patch-module java.desktop=${CATALINA_HOME}/lib/marlin.jar \
       -Dsun.java2d.renderer=org.marlin.pisces.PiscesRenderingEngine \
       -Dsun.java2d.renderer.log=true \
       -Dgeoserver.login.autocomplete=${LOGIN_STATUS} \
       -DUPDATE_BUILT_IN_LOGGING_PROFILES=${UPDATE_LOGGING_PROFILES} \
       -DRELINQUISH_LOG4J_CONTROL=${RELINQUISH_LOG4J_CONTROL} \
       -DGEOSERVER_CONSOLE_DISABLED=${DISABLE_WEB_INTERFACE} \
       -DGWC_DISKQUOTA_DISABLED=${DISKQUOTA_DISABLED} \
       -DGEOSERVER_CSRF_WHITELIST=${CSRF_WHITELIST} \
       -Dgeoserver.xframe.shouldSetPolicy=${XFRAME_OPTIONS} \
       -DGEOSERVER_REQUIRE_FILE=${GEOSERVER_REQUIRE_FILE} \
       -DENTITY_RESOLUTION_ALLOWLIST='"${ENTITY_RESOLUTION_ALLOWLIST}"' \
       -DGEOSERVER_DISABLE_STATIC_WEB_FILES=${GEOSERVER_DISABLE_STATIC_WEB_FILES} \
       -DGEOSERVER_DATA_DIR_LOADER_ENABLED=${GEOSERVER_DATA_DIR_LOADER_ENABLED} \
       -DGEOSERVER_DATA_DIR_LOADER_THREADS=${GEOSERVER_DATA_DIR_LOADER_THREADS} \
       ${ADDITIONAL_JAVA_STARTUP_OPTIONS} "
  fi
  ## Prepare the JVM command line arguments
  export JAVA_OPTS="${JAVA_OPTS} ${GEOSERVER_OPTS}"
}

configure_telemetry() {
  [[ ${TELEMETRY_TRACING_ENABLED} =~ [Tt][Rr][Uu][Ee] ]] && \
    JAVA_OPTS+=" -javaagent:${OTEL_DIR}/opentelemetry-javaagent.jar"

  [[ ${TELEMETRY_METRICS_ENABLED} =~ [Tt][Rr][Uu][Ee] ]] && \
    JAVA_OPTS+=" -javaagent:${JMX_DIR}/jmx_prometheus_javaagent.jar=${TELEMETRY_METRICS_PORT}:${JMX_DIR}/config.yaml"

  export JAVA_OPTS
}

############################################
# 8. PACKAGING HELPERS
############################################

package_tomcat_webapp() {
  if [[ -d "${CATALINA_HOME}"/webapps.dist ]]; then
    mv "${CATALINA_HOME}"/webapps.dist /tomcat_apps
    zip -r "${REQUIRED_PLUGINS_DIR}"/tomcat_apps.zip /tomcat_apps
    rm -r /tomcat_apps
  else
    cp -r "${CATALINA_HOME}"/webapps/ROOT /tomcat_apps
    cp -r "${CATALINA_HOME}"/webapps/docs /tomcat_apps
    cp -r "${CATALINA_HOME}"/webapps/examples /tomcat_apps
    cp -r "${CATALINA_HOME}"/webapps/host-manager /tomcat_apps
    cp -r "${CATALINA_HOME}"/webapps/manager /tomcat_apps
    zip -r "${REQUIRED_PLUGINS_DIR}"/tomcat_apps.zip /tomcat_apps
    rm -rf /tomcat_apps
  fi
}


patch_tomcat_server_info() {
  pushd "${CATALINA_HOME}/lib" || exit
  create_dir org/apache/catalina/util/
  unzip -p catalina.jar org/apache/catalina/util/ServerInfo.properties \
  | sed 's/^server.info=.*/server.info=Apache Tomcat/' \
  > ServerInfo.properties && \
  zip -d catalina.jar org/apache/catalina/util/ServerInfo.properties && \
  zip -ur catalina.jar ServerInfo.properties && \
  rm ServerInfo.properties

}

set_restrictive_umask() {
  echo "session optional pam_umask.so" >> /etc/pam.d/common-session
  sed -i 's/UMASK.*022/UMASK           007/g' /etc/login.defs
}

############################################
# 9. STARTUP
############################################
rename_geoserver_context_root() {
  if [[ "${GEOSERVER_CONTEXT_ROOT}" != "geoserver" ]]; then
    #log "Changing context-root to ${GEOSERVER_CONTEXT_ROOT}"
    echo "Changing context-root to ${GEOSERVER_CONTEXT_ROOT}"
    local install_dir
    install_dir="$(detect_install_dir)"

    if [[ -d "${install_dir}/webapps/geoserver" ]]; then
      mv "${install_dir}/webapps/geoserver" \
         "${install_dir}/webapps/${GEOSERVER_CONTEXT_ROOT}"
    else
      #log_warn "Context already renamed or first-run skipped"
      echo "Context already renamed or first-run skipped"
    fi
  fi
}

start_geoserver_service() {
if [[ ${RUN_AS_ROOT} =~ [Ff][Aa][Ll][Ss][Ee] ]];then
  if [[ -f ${GEOSERVER_HOME}/start.jar ]]; then
    exec gosu "${USER_NAME}" "${GEOSERVER_HOME}"/bin/startup.sh
  else
    exec gosu "${USER_NAME}" /usr/local/tomcat/bin/catalina.sh run
  fi
else
  if [[ -f ${GEOSERVER_HOME}/start.jar ]]; then
    exec  "${GEOSERVER_HOME}"/bin/startup.sh
  else
    exec  /usr/local/tomcat/bin/catalina.sh run
  fi
fi

}