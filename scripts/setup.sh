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
create_dir "${FONTS_DIR}"
create_dir "${REQUIRED_PLUGINS_DIR}"

pushd "${CATALINA_HOME}" || exit


# Download geoserver and install it
package_geoserver

# Copy config files
cp /build_data/stable_plugins.txt "${STABLE_PLUGINS_DIR}"
cp /build_data/community_plugins.txt "${COMMUNITY_PLUGINS_DIR}"
cp /build_data/letsencrypt-tomcat.xsl "${CATALINA_HOME}"/conf/ssl-tomcat.xsl

pushd "${STABLE_PLUGINS_DIR}" || exit

# Install libjpeg-turbo
system_architecture=$(dpkg --print-architecture)
# Fixes https://github.com/kartoza/docker-geoserver/issues/673
libjpeg_version=2.1.5.1
libjpeg_deb_name="libjpeg-turbo-official_${libjpeg_version}_${system_architecture}.deb"
libjpeg_deb="${resources_dir}/${libjpeg_deb_name}"
if [[ ! -f "${libjpeg_deb}" ]]; then
  curl -vfLo "${libjpeg_deb}" "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/${libjpeg_version}/${libjpeg_deb_name}"
fi

dpkg -i "${libjpeg_deb}"

pushd "${CATALINA_HOME}" || exit

# Install GeoServer plugins in correct install dir
GEOSERVER_INSTALL_DIR="$(detect_install_dir)"


lib_dir="${GEOSERVER_INSTALL_DIR}/webapps/${GEOSERVER_CONTEXT_ROOT}/WEB-INF/lib"

# Search for gdal-<version>.jar files in the lib directory
for jar_file in "$lib_dir"/gdal-*.jar; do
    if [[ -f "$jar_file" ]]; then
        # Extract the version number
        version=$(basename "$jar_file" | sed 's/gdal-\(.*\)\.jar/\1/')
        break
    fi
done

GDAL_VERSION=$(gdalinfo --version | head -n1 | cut -d" " -f2 | tr -d ,,)

if [[ ${GDAL_VERSION} != ${version} ]];then
  rm ${lib_dir}/gdal-${version}.jar
  curl -vfLo "${lib_dir}/gdal-${GDAL_VERSION:0:3}.0.jar" "https://repo1.maven.org/maven2/org/gdal/gdal/${GDAL_VERSION:0:3}.0/gdal-${GDAL_VERSION:0:3}.0.jar"
fi


# Install Marlin render https://www.geocat.net/docs/geoserver-enterprise/2020.5/install/production/marlin.html
curl --progress-bar -fLvo ${CATALINA_HOME}/lib/marlin.jar https://github.com/bourgesl/marlin-renderer/releases/download/v0_9_4_8/marlin-0.9.4.8-Unsafe-OpenJDK11.jar || exit 1

# Install jetty-servlets
if [[ -f ${GEOSERVER_HOME}/start.jar ]]; then
    cp /work/required_plugins/jetty-servlets-11.0.9.jar "${GEOSERVER_HOME}"/webapps/"${GEOSERVER_CONTEXT_ROOT}"/WEB-INF/lib/
fi

# Install jetty-util
if [[ -f ${GEOSERVER_HOME}/start.jar ]]; then
    cp /work/required_plugins/jetty-util.jar "${GEOSERVER_HOME}"/webapps/"${GEOSERVER_CONTEXT_ROOT}"/WEB-INF/lib/
fi

# Overlay files and directories in resources/overlays if they exist
rm -f /tmp/resources/overlays/README.txt &&
  if ls /tmp/resources/overlays/* >/dev/null 2>&1; then
    cp -rf /tmp/resources/overlays/* /
  fi


# Package tomcat webapps - useful to activate later
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