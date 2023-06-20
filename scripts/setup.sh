#!/usr/bin/env bash
# Download geoserver extensions and other resources

source /scripts/env-data.sh
source /scripts/functions.sh

resources_dir="/tmp/resources"
GS_VERSION=$(cat /scripts/geoserver_version.txt)
create_dir ${resources_dir}/plugins/gdal
create_dir /usr/share/fonts/opentype
create_dir /tomcat_apps
create_dir "${CATALINA_HOME}"/postgres_config
create_dir "${STABLE_PLUGINS_DIR}"
create_dir "${COMMUNITY_PLUGINS_DIR}"
create_dir "${GEOSERVER_HOME}"
create_dir "${GEOSERVER_DATA_DIR}"

pushd "${CATALINA_HOME}" || exit

# Copy config files
cp /build_data/stable_plugins.txt /stable_plugins && cp /build_data/community_plugins.txt /community_plugins && \
cp /build_data/letsencrypt-tomcat.xsl ${CATALINA_HOME}/conf/ssl-tomcat.xsl

validate_url http://ftp.br.debian.org/debian/pool/contrib/m/msttcorefonts/ttf-mscorefonts-installer_3.8.1_all.deb && \
 dpkg -i ttf-mscorefonts-installer_3.8.1_all.deb && rm ttf-mscorefonts-installer_3.8.1_all.deb


pushd "${STABLE_PLUGINS_DIR}" || exit

# Check if we have pre downloaded plugin yet
stable_count=$(ls -1 $resources_dir/plugins/stable_plugins/*.zip 2>/dev/null | wc -l)
if [ "$stable_count" != 0 ]; then
  cp -r $resources_dir/plugins/stable_plugins/*.zip /stable_plugins/
fi

community_count=$(ls -1 $resources_dir/plugins/community_plugins/*.zip 2>/dev/null | wc -l)
if [ "${community_count}" != 0 ]; then
  cp -r $resources_dir/plugins/community_plugin/*.zip /community_plugins/
fi

# Download all other stable plugins to keep for activating using env variables, excludes the mandatory stable ones installed

if [ -z "${DOWNLOAD_ALL_STABLE_EXTENSIONS}" ] || [ "${DOWNLOAD_ALL_STABLE_EXTENSIONS}" -eq 0 ]; then
  plugin=$(head -n 1 /stable_plugins/stable_plugins.txt)
  approved_plugins_url="${STABLE_PLUGIN_BASE_URL}/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-${plugin}.zip"
  download_extension "${approved_plugins_url}" "${plugin}" /stable_plugins
else
  for plugin in $(cat /stable_plugins/stable_plugins.txt); do
    approved_plugins_url="${STABLE_PLUGIN_BASE_URL}/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-${plugin}.zip"
    download_extension "${approved_plugins_url}" "${plugin}" /stable_plugins
  done
fi

# Download community extensions. This needs to be checked on each iterations as they sometimes become unavailable
pushd "${COMMUNITY_PLUGINS_DIR}" || exit

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



# Install libjpeg-turbo
system_architecture=$(dpkg --print-architecture)
if [[ ! -f ${resources_dir}/libjpeg-turbo-official_2.1.3_amd64.deb ]]; then
  validate_url https://tenet.dl.sourceforge.net/project/libjpeg-turbo/2.1.4/libjpeg-turbo-official_2.1.4_${system_architecture}.deb \
    '-P /tmp/resources/'
fi

dpkg -i ${resources_dir}/libjpeg-turbo-official_2.1.4_${system_architecture}.deb

# Install Marlin render https://www.geocat.net/docs/geoserver-enterprise/2020.5/install/production/marlin.html
JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
if [[ ${JAVA_VERSION} > 10 ]];then
    if [[  -f $(find ${GEOSERVER_INSTALL_DIR}/webapps/${GEOSERVER_CONTEXT_ROOT}/WEB-INF/lib -regex ".*marlin-[0-9]\.[0-9]\.[0-9].*jar") ]]; then
      mv ${GEOSERVER_INSTALL_DIR}/webapps/${GEOSERVER_CONTEXT_ROOT}/WEB-INF/lib/marlin-* ${GEOSERVER_INSTALL_DIR}/webapps/${GEOSERVER_CONTEXT_ROOT}/WEB-INF/lib/marlin-render.jar
    fi
else
    if [[ -f $(find ${GEOSERVER_INSTALL_DIR}/webapps/${GEOSERVER_CONTEXT_ROOT}/WEB-INF/lib -regex ".*marlin-[0-9]\.[0-9]\.[0-9].*jar") ]]; then
      rm "${GEOSERVER_INSTALL_DIR}"/webapps/${GEOSERVER_CONTEXT_ROOT}/WEB-INF/lib/marlin-* \
      validate_url https://github.com/bourgesl/marlin-renderer/releases/download/v0_9_4_2_jdk9/marlin-0.9.4.2-Unsafe-OpenJDK9.jar && \
      mv marlin-0.9.4.2-Unsafe-OpenJDK9.jar ${GEOSERVER_INSTALL_DIR}/webapps/${GEOSERVER_CONTEXT_ROOT}/WEB-INF/lib/marlin-render.jar
    fi
fi

pushd "${CATALINA_HOME}" || exit

# Install GeoServer plugins in correct install dir
GEOSERVER_INSTALL_DIR="$(detect_install_dir)"



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

artifact_url="https://artifacts.geonode.org/geoserver/$GS_VERSION/geonode-geoserver-ext-web-app-data.zip"
curl  -k -L "$artifact_url" --output data.zip && unzip -x -d ${resources_dir} data.zip


cp -r ${resources_dir}/data "${CATALINA_HOME}"/
cp -r ${resources_dir}/data/* "${GEOSERVER_DATA_DIR}"


# Delete resources after installation
rm -rf /tmp/resources

delete_file "${CATALINA_HOME}"/conf/tomcat-users.xml
#delete_file "${CATALINA_HOME}"/conf/web.xml

