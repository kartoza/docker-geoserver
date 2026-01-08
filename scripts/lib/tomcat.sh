#!/usr/bin/env bash


# Function to add users when tomcat manager is configured
# https://tomcat.apache.org/tomcat-8.0-doc/manager-howto.html
tomcat_user_config() {
  [[ -f "${CATALINA_HOME}/conf/tomcat-users.xml" ]] && return

  if [[ -f "${EXTRA_CONFIG_DIR}/tomcat-users.xml" ]]; then
    envsubst < "${EXTRA_CONFIG_DIR}/tomcat-users.xml" > "${CATALINA_HOME}/conf/tomcat-users.xml"
  else
    envsubst < /build_data/tomcat-users.xml > "${CATALINA_HOME}/conf/tomcat-users.xml"
  fi
}



# Function to enable cors support thought tomcat
# https://documentation.bonitasoft.com/bonita/2021.1/enable-cors-in-tomcat-bundle
web_cors() {
  local web_xml="${CATALINA_HOME}/conf/web.xml"

  if [[ -f "${web_xml}" ]]; then
    return
  fi

  if [[ -f "${EXTRA_CONFIG_DIR}/web.xml" ]]; then
    cp -f "${EXTRA_CONFIG_DIR}/web.xml" "${web_xml}"
  else
    envsubst < /build_data/web.xml > "${web_xml}"

    if [[ "${DISABLE_CORS}" =~ [Tt][Rr][Uu][Ee] ]]; then
      sed -i \
        's/<!-- CORS_START.*/<!-- CORS DEACTIVATED BY DISABLE_CORS -->\n<!--/;
         s/^.*<!-- CORS_END -->/-->/' \
        "${web_xml}"
    fi

    if [[ "${DISABLE_SECURITY_FILTER}" =~ [Tt][Rr][Uu][Ee] ]]; then
      sed -i \
        's/<!-- SECURITY_START.*/<!-- SECURITY FILTER DEACTIVATED BY DISABLE_SECURITY_FILTER -->\n<!--/;
         s/^.*<!-- SECURITY_END -->/-->/' \
        "${web_xml}"
    fi
  fi
}

package_webapp(){
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

