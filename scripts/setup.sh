#!/usr/bin/env bash
# Download geoserver extensions and other resources

source /scripts/functions.sh

resources_dir="/tmp/resources"
create_dir ${resources_dir}/plugins/gdal
create_dir /usr/share/fonts/opentype
create_dir /tomcat_apps



pushd /plugins

# Download all other stable plugins to keep for activating using env variables, excludes the mandatory stable ones installed

if [ -z "${ACTIVATE_ALL_STABLE_EXTENTIONS}" ] || [ ${ACTIVATE_ALL_STABLE_EXTENTIONS} -eq 0 ]; then
  plugin=$(head -n 1 stable_plugins.txt)
  approved_plugins_url="https://liquidtelecom.dl.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-${plugin}.zip"
  download_extension ${approved_plugins_url} ${plugin}
else
  for plugin in $(cat stable_plugins.txt); do
    approved_plugins_url="https://liquidtelecom.dl.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-${plugin}.zip"
    download_extension ${approved_plugins_url} ${plugin}
  done
fi

# Download community extensions. This needs to be checked on each iterations as they sometimes become unavailable
pushd /community_plugins

if [ -z "${ACTIVATE_ALL_COMMUNITY_EXTENTIONS}" ] || [ ${ACTIVATE_ALL_COMMUNITY_EXTENTIONS} -eq 0 ]; then
  plugin=$(head -n 1 community_plugins.txt)
  community_plugins_url="https://build.geoserver.org/geoserver/${GS_VERSION:0:5}x/community-latest/geoserver-${GS_VERSION:0:4}-SNAPSHOT-${plugin}.zip"
  download_extension ${community_plugins_url} ${plugin}
else
  for plugin in $(cat community_plugins.txt); do
    community_plugins_url="https://build.geoserver.org/geoserver/${GS_VERSION:0:5}x/community-latest/geoserver-${GS_VERSION:0:4}-SNAPSHOT-${plugin}.zip"
    download_extension ${community_plugins_url} ${plugin}

  done
fi

#Install some mandatory stable extensions
pushd ${resources_dir}/plugins

array=(geoserver-$GS_VERSION-vectortiles-plugin.zip geoserver-$GS_VERSION-wps-plugin.zip geoserver-$GS_VERSION-printing-plugin.zip
  geoserver-$GS_VERSION-libjpeg-turbo-plugin.zip geoserver-$GS_VERSION-control-flow-plugin.zip
  geoserver-$GS_VERSION-pyramid-plugin.zip geoserver-$GS_VERSION-gdal-plugin.zip
  geoserver-$GS_VERSION-monitor-plugin.zip geoserver-$GS_VERSION-inspire-plugin.zip geoserver-$GS_VERSION-csw-plugin.zip )
for i in "${array[@]}"; do
  url="https://liquidtelecom.dl.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/extensions/${i}"
  download_extension ${url} ${i%.*}
done



pushd gdal

${request} http://demo.geo-solutions.it/share/github/imageio-ext/releases/1.1.X/1.1.15/native/gdal/gdal-data.zip
popd
${request} http://demo.geo-solutions.it/share/github/imageio-ext/releases/1.1.X/1.1.29/native/gdal/linux/gdal192-Ubuntu12-gcc4.6.3-x86_64.tar.gz

popd

# Install libjpeg-turbo
if [[ ! -f /tmp/resources/libjpeg-turbo-official_1.5.3_amd64.deb ]]; then
  ${request} https://sourceforge.net/projects/libjpeg-turbo/files/1.5.3/libjpeg-turbo-official_1.5.3_amd64.deb \
    -P ${resources_dir}
fi

dpkg -i ${resources_dir}/libjpeg-turbo-official_1.5.3_amd64.deb



pushd ${CATALINA_HOME}

# Download geoserver
download_geoserver

# Install geoserver in the tomcat dir
unzip /tmp/geoserver/geoserver.war -d ${CATALINA_HOME}/webapps/geoserver &&
  cp -r ${CATALINA_HOME}/webapps/geoserver/data ${CATALINA_HOME} &&
  mv ${CATALINA_HOME}/data/security ${CATALINA_HOME} &&
  rm -rf ${CATALINA_HOME}/webapps/geoserver/data &&
  rm -rf /tmp/geoserver

# Install any plugin zip files in resources/plugins
if ls /tmp/resources/plugins/*.zip >/dev/null 2>&1; then
  for p in /tmp/resources/plugins/*.zip; do
    unzip $p -d /tmp/gs_plugin &&
      mv /tmp/gs_plugin/*.jar ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/ &&
      rm -rf /tmp/gs_plugin
  done
fi

# Temporary fix for the print plugin https://github.com/georchestra/georchestra/pull/2517

rm ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/json-20180813.jar && \
${request} https://repo1.maven.org/maven2/org/json/json/20080701/json-20080701.jar \
-O ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/json-20080701.jar

# Activate gdal plugin in geoserver
if ls /tmp/resources/plugins/*gdal*.tar.gz >/dev/null 2>&1; then
  mkdir /usr/local/gdal_data && mkdir /usr/local/gdal_native_libs
  unzip /tmp/resources/plugins/gdal/gdal-data.zip -d /usr/local/gdal_data &&
    mv /usr/local/gdal_data/gdal-data/* /usr/local/gdal_data && rm -rf /usr/local/gdal_data/gdal-data &&
    tar xzf /tmp/resources/plugins/gdal192-Ubuntu12-gcc4.6.3-x86_64.tar.gz -C /usr/local/gdal_native_libs
fi
# Install Marlin render
if [[ ! -f ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/marlin-sun-java2d.jar ]]; then
  ${request} https://github.com/bourgesl/marlin-renderer/releases/download/v0_9_4_2_jdk9/marlin-0.9.4.2-Unsafe-OpenJDK9.jar \
    -O ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/marlin-0.9.4.2-Unsafe-OpenJDK9.jar
fi

# Install sqljdbc
if [[ ! -f ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/sqljdbc.jar ]]; then
  ${request} https://clojars.org/repo/com/microsoft/sqlserver/sqljdbc4/4.0/sqljdbc4-4.0.jar \
    -O ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/sqljdbc.jar
fi

# Install jetty-servlets
if [[ ! -f ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/jetty-servlets.jar ]]; then
  ${request} https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-servlets/9.4.21.v20190926/jetty-servlets-9.4.21.v20190926.jar \
    -O ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/jetty-servlets.jar
fi

# Install jetty-util
if [[ ! -f ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/jetty-util.jar ]]; then
  ${request} https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-util/9.4.21.v20190926/jetty-util-9.4.21.v20190926.jar \
    -O ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/jetty-util.jar
fi

# Overlay files and directories in resources/overlays if they exist
rm -f /tmp/resources/overlays/README.txt &&
  if ls /tmp/resources/overlays/* >/dev/null 2>&1; then
    cp -rf /tmp/resources/overlays/* /
  fi


# Package tomcat webapps - useful to activate later
if [ -d $CATALINA_HOME/webapps.dist ]; then
    cp -r $CATALINA_HOME/webapps.dist /tomcat_apps &&
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
