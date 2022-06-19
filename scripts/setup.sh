#!/usr/bin/env bash
# Download geoserver extensions and other resources

source /scripts/env-data.sh
source /scripts/functions.sh

resources_dir="/tmp/resources"
create_dir ${resources_dir}/plugins/gdal
create_dir /usr/share/fonts/opentype
create_dir /tomcat_apps
create_dir /usr/local/gdal_data
create_dir /usr/local/gdal_native_libs
create_dir "${CATALINA_HOME}"/postgres_config

validate_url http://ftp.br.debian.org/debian/pool/contrib/m/msttcorefonts/ttf-mscorefonts-installer_3.8_all.deb && \
 dpkg -i ttf-mscorefonts-installer_3.8_all.deb && rm ttf-mscorefonts-installer_3.8_all.deb


pushd /plugins || exit

# Check if we have pre downloaded plugin yet
stable_count=$(ls -1 $resources_dir/plugins/stable_plugins/*.zip 2>/dev/null | wc -l)
if [ "$stable_count" != 0 ]; then
  cp -r $resources_dir/plugins/stable_plugins/*.zip /plugins/
fi

community_count=$(ls -1 $resources_dir/plugins/community_plugins/*.zip 2>/dev/null | wc -l)
if [ "${community_count}" != 0 ]; then
  cp -r $resources_dir/plugins/community_plugin/*.zip /plugins/
fi

# Download all other stable plugins to keep for activating using env variables, excludes the mandatory stable ones installed

if [ -z "${DOWNLOAD_ALL_STABLE_EXTENSIONS}" ] || [ "${DOWNLOAD_ALL_STABLE_EXTENSIONS}" -eq 0 ]; then
  plugin=$(head -n 1 /plugins/stable_plugins.txt)
  approved_plugins_url="${STABLE_PLUGIN_BASE_URL}/project/geoserver/GeoServer/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-${plugin}.zip"
  download_extension "${approved_plugins_url}" "${plugin}" /plugins
else
  for plugin in $(cat /plugins/stable_plugins.txt); do
    approved_plugins_url="${STABLE_PLUGIN_BASE_URL}/project/geoserver/GeoServer/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-${plugin}.zip"
    download_extension "${approved_plugins_url}" "${plugin}" /plugins
  done
fi

# Download community extensions. This needs to be checked on each iterations as they sometimes become unavailable
pushd /community_plugins || exit

if [ -z "${DOWNLOAD_ALL_COMMUNITY_EXTENSIONS}" ] || [ "${DOWNLOAD_ALL_COMMUNITY_EXTENSIONS}" -eq 0 ]; then
  plugin=$(head -n 1 /community_plugins/community_plugins.txt)
  community_plugins_url="https://build.geoserver.org/geoserver/${GS_VERSION:0:5}x/community-latest/geoserver-${GS_VERSION:0:4}-SNAPSHOT-${plugin}.zip"
  download_extension "${community_plugins_url}" "${plugin}" /community_plugins
else
  for plugin in $(cat /community_plugins/community_plugins.txt); do
    community_plugins_url="https://build.geoserver.org/geoserver/${GS_VERSION:0:5}x/community-latest/geoserver-${GS_VERSION:0:4}-SNAPSHOT-${plugin}.zip"
    download_extension "${community_plugins_url}" "${plugin}" /community_plugins

  done
fi

#Install some mandatory stable extensions
pushd ${resources_dir}/plugins || exit

array=(geoserver-${GS_VERSION}-vectortiles-plugin.zip geoserver-${GS_VERSION}-wps-plugin.zip geoserver-${GS_VERSION}-printing-plugin.zip
  geoserver-${GS_VERSION}-libjpeg-turbo-plugin.zip geoserver-${GS_VERSION}-control-flow-plugin.zip
  geoserver-${GS_VERSION}-pyramid-plugin.zip geoserver-${GS_VERSION}-gdal-plugin.zip
  geoserver-${GS_VERSION}-monitor-plugin.zip geoserver-${GS_VERSION}-inspire-plugin.zip geoserver-${GS_VERSION}-csw-plugin.zip )
for i in "${array[@]}"; do
  url="${STABLE_PLUGIN_BASE_URL}/project/geoserver/GeoServer/${GS_VERSION}/extensions/${i}"
  download_extension "${url}" "${i%.*}" ${resources_dir}/plugins
done


# Install libjpeg-turbo
if [[ ! -f ${resources_dir}/libjpeg-turbo-official_2.1.3_amd64.deb ]]; then
  validate_url https://liquidtelecom.dl.sourceforge.net/project/libjpeg-turbo/2.1.3/libjpeg-turbo-official_2.1.3_amd64.deb \
    '-P /tmp/resources/'
fi

dpkg -i ${resources_dir}/libjpeg-turbo-official_2.1.3_amd64.deb

pushd "${CATALINA_HOME}" || exit

# Download geoserver
download_geoserver

# Install geoserver in the tomcat dir
if [[ -f /tmp/geoserver/geoserver.war ]]; then
  unzip /tmp/geoserver/geoserver.war -d "${CATALINA_HOME}"/webapps/geoserver &&
  cp -r "${CATALINA_HOME}"/webapps/geoserver/data "${CATALINA_HOME}" &&
  mv "${CATALINA_HOME}"/data/security "${CATALINA_HOME}" &&
  rm -rf "${CATALINA_HOME}"/webapps/geoserver/data &&
  mv "${CATALINA_HOME}"/webapps/geoserver/WEB-INF/lib/postgresql-* "${CATALINA_HOME}"/postgres_config/ &&
  rm -rf /tmp/geoserver
else
  cp -r /tmp/geoserver/* "${GEOSERVER_HOME}"/ &&
  cp -r "${GEOSERVER_HOME}"/webapps/geoserver "${CATALINA_HOME}"/webapps/geoserver &&
  cp -r "${GEOSERVER_HOME}"/data_dir "${CATALINA_HOME}"/data &&
  mv "${CATALINA_HOME}"/data/security "${CATALINA_HOME}"
fi

# Install GeoServer plugins in correct install dir
if [[ -f ${GEOSERVER_HOME}/start.jar ]]; then
  GEOSERVER_INSTALL_DIR=${GEOSERVER_HOME}
else
  GEOSERVER_INSTALL_DIR=${CATALINA_HOME}
fi

# Install any plugin zip files in resources/plugins
if ls /tmp/resources/plugins/*.zip >/dev/null 2>&1; then
  for p in /tmp/resources/plugins/*.zip; do
    unzip "$p" -d /tmp/gs_plugin &&
      mv /tmp/gs_plugin/*.jar "${GEOSERVER_INSTALL_DIR}"/webapps/geoserver/WEB-INF/lib/ &&
      rm -rf /tmp/gs_plugin
  done
fi

# Download appropriate gdal-jar
GDAL_VERSION=$(gdalinfo --version | head -n1 | cut -d" " -f2)
if [[ ${GDAL_VERSION:0:3} == 3.2 ]];then
  echo "gdal versions are the same"
else
  rm /usr/local/tomcat/webapps/geoserver/WEB-INF/lib/gdal-*
  validate_url https://repo1.maven.org/maven2/org/gdal/gdal/${GDAL_VERSION:0:3}.0/gdal-${GDAL_VERSION:0:3}.0.jar \
  '-O "${GEOSERVER_HOME}"/webapps/geoserver/WEB-INF/lib/gdal-${GDAL_VERSION:0:3}.0.jar'
fi


# Install Marlin render https://www.geocat.net/docs/geoserver-enterprise/2020.5/install/production/marlin.html
JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
if [[ ${JAVA_VERSION} > 10 ]];then
    if [[  -f $(find ${GEOSERVER_INSTALL_DIR}/webapps/geoserver/WEB-INF/lib -regex ".*marlin-[0-9]\.[0-9]\.[0-9].*jar") ]]; then
      mv ${GEOSERVER_INSTALL_DIR}/webapps/geoserver/WEB-INF/lib/marlin-* ${GEOSERVER_INSTALL_DIR}/webapps/geoserver/WEB-INF/lib/marlin-render.jar
    fi
else
    if [[ -f $(find ${GEOSERVER_INSTALL_DIR}/webapps/geoserver/WEB-INF/lib -regex ".*marlin-[0-9]\.[0-9]\.[0-9].*jar") ]]; then
      rm "${GEOSERVER_INSTALL_DIR}"/webapps/geoserver/WEB-INF/lib/marlin-* \
      validate_url https://github.com/bourgesl/marlin-renderer/releases/download/v0_9_4_2_jdk9/marlin-0.9.4.2-Unsafe-OpenJDK9.jar && \
      mv marlin-0.9.4.2-Unsafe-OpenJDK9.jar ${GEOSERVER_INSTALL_DIR}/webapps/geoserver/WEB-INF/lib/marlin-render.jar
    fi
fi

# Install jetty-servlets
if [[ -f ${GEOSERVER_HOME}/start.jar ]]; then
  if [[ ! -f ${GEOSERVER_HOME}/webapps/geoserver/WEB-INF/lib/jetty-servlets.jar ]]; then
    validate_url https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-servlets/11.0.9/jetty-servlets-11.0.9.jar \
    '-O "${GEOSERVER_HOME}"/webapps/geoserver/WEB-INF/lib/jetty-servlets.jar'
  fi
fi

# Install jetty-util
if [[ -f ${GEOSERVER_HOME}/start.jar ]]; then
  if [[ ! -f ${GEOSERVER_HOME}/webapps/geoserver/WEB-INF/lib/jetty-util.jar ]]; then
    validate_url https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-util/11.0.9/jetty-util-11.0.9.jar \
      '-O "${GEOSERVER_HOME}"/webapps/geoserver/WEB-INF/lib/jetty-util.jar'
  fi
fi

# Overlay files and directories in resources/overlays if they exist
rm -f /tmp/resources/overlays/README.txt &&
  if ls /tmp/resources/overlays/* >/dev/null 2>&1; then
    cp -rf /tmp/resources/overlays/* /
  fi


# Package tomcat webapps - useful to activate later
if [ -d "$CATALINA_HOME"/webapps.dist ]; then
    mv "$CATALINA_HOME"/webapps.dist /tomcat_apps &&
    zip -r /tomcat_apps.zip /tomcat_apps && rm -r /tomcat_apps
else
    cp -r "${CATALINA_HOME}"/webapps/ROOT /tomcat_apps &&
    cp -r "${CATALINA_HOME}"/webapps/docs /tomcat_apps &&
    cp -r "${CATALINA_HOME}"/webapps/examples /tomcat_apps &&
    cp -r "${CATALINA_HOME}"/webapps/host-manager /tomcat_apps &&
    cp -r "${CATALINA_HOME}"/webapps/manager /tomcat_apps &&
    zip -r /tomcat_apps.zip /tomcat_apps && rm -r /tomcat_apps
fi

# Delete resources after installation
rm -rf /tmp/resources

# Delete resources which will be setup on first run

delete_file "${CATALINA_HOME}"/conf/tomcat-users.xml
delete_file "${CATALINA_HOME}"/conf/web.xml
