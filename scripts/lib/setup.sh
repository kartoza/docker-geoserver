#!/usr/bin/env bash
# Download geoserver extensions and other resources

SCRIPT_DIR="/scripts"
source "${SCRIPT_DIR}/lib/env-data.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/logging.sh"
source "${SCRIPT_DIR}/lib/database.sh"
source "${SCRIPT_DIR}/lib/geoserver.sh"
source "${SCRIPT_DIR}/lib/tomcat.sh"
source "${SCRIPT_DIR}/lib/cluster.sh"

resources_dir="/tmp/resources"
GS_VERSION=$(cat /scripts/geoserver_version.txt)
path=("${resources_dir}/plugins/gdal" "/usr/share/fonts/opentype" "/tomcat_apps" ""${CATALINA_HOME}"/postgres_config" \
 "${STABLE_PLUGINS_DIR}" "${COMMUNITY_PLUGINS_DIR}" "${GEOSERVER_HOME}" "${FONTS_DIR}" "${REQUIRED_PLUGINS_DIR}")
 for dir in "${path[@]}"; do
  echo "Creating directory: $dir"
  create_dir ${dir}
done


pushd "${CATALINA_HOME}" || exit

# Download geoserver and install it
package_geoserver

# Copy config files
cp /build_data/stable_plugins.txt "${STABLE_PLUGINS_DIR}"
cp /build_data/community_plugins.txt "${COMMUNITY_PLUGINS_DIR}"
cp /build_data/letsencrypt-tomcat.xsl "${CATALINA_HOME}"/conf/ssl-tomcat.xsl

pushd "${STABLE_PLUGINS_DIR}" || exit

install_turbo

pushd "${CATALINA_HOME}" || exit

# Install Marlin render https://www.geocat.net/docs/geoserver-enterprise/2020.5/install/production/marlin.html
cp ${REQUIRED_PLUGINS_DIR}/marlin.jar ${CATALINA_HOME}/lib/marlin.jar

# Install jetty-servlets
if [[ -f ${GEOSERVER_HOME}/start.jar ]]; then
    cp ${REQUIRED_PLUGINS_DIR}/jetty-servlets-11.0.9.jar "${GEOSERVER_HOME}"/webapps/"${GEOSERVER_CONTEXT_ROOT}"/WEB-INF/lib/
fi

# Install jetty-util
if [[ -f ${GEOSERVER_HOME}/start.jar ]]; then
    cp ${REQUIRED_PLUGINS_DIR}/jetty-util.jar "${GEOSERVER_HOME}"/webapps/"${GEOSERVER_CONTEXT_ROOT}"/WEB-INF/lib/
fi

# Overlay files and directories in resources/overlays if they exist
rm -f /tmp/resources/overlays/README.txt &&
  if ls /tmp/resources/overlays/* >/dev/null 2>&1; then
    cp -rf /tmp/resources/overlays/* /
  fi


# Package tomcat webapps - useful to activate later
package_webapp

pushd ${CATALINA_HOME}/lib  || exit
create_dir org/apache/catalina/util/ && \
unzip -j catalina.jar org/apache/catalina/util/ServerInfo.properties -d org/apache/catalina/util/ && \
sed -i 's/server.info=.*/server.info=Apache Tomcat/g' org/apache/catalina/util/ServerInfo.properties && \
zip -ur catalina.jar org/apache/catalina/util/ServerInfo.properties && rm -rf org
# Setting restrictive umask container-wide
echo "session optional pam_umask.so" >> /etc/pam.d/common-session && \
sed -i 's/UMASK.*022/UMASK           007/g' /etc/login.defs

pushd /scripts || exit
# Delete resources after installation
rm -rf /tmp/resources

# Delete resources which will be setup on first run
delete_file "${CATALINA_HOME}"/conf/web.xml