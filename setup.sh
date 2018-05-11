#!/usr/bin/env bash
# Download geoserver extensions and other resources

if [ ! -d ${GEOSERVER_DATA_DIR} ];
then
    echo "Creating geoserver data directory"
    mkdir -p ${GEOSERVER_DATA_DIR}
else
    echo "Geoserver data directory already exist"
fi

pushd /

#Java
#Webupd8
#wget -c https://launchpad.net/~webupd8team/+archive/ubuntu/java/+files/oracle-java8-installer_8u101+8u101arm-1~webupd8~2.tar.xz
#Oracle
#wget -c http://download.oracle.com/otn-pub/java/jdk/8u112-b15/jdk-8u112-linux-x64.tar.gz
# If a matching Oracle JDK tar.gz exists in /tmp/resources, move it to /var/cache/oracle-jdk8-installer
# where oracle-java8-installer will detect it
if [ ! -f ./resources/jre-8u161-linux-x64.tar.gz ]; then \
    wget -c --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/8u171-b11/512cd62ec5174c3487ac17c61aaa89e8/jre-8u171-linux-x64.tar.gz -P ./resources;\
    fi;

if ls ./resources/*jdk-*-linux-x64.tar.gz > /dev/null 2>&1; then \

      mkdir /var/cache/oracle-jdk8-installer && \
      mv ./resources/*jdk-*-linux-x64.tar.gz /var/cache/oracle-jdk8-installer/; \
    fi;


#Policy

if [ ! -f ./resources/jce_policy.zip ]; then \
    wget -c --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip -O ./resources/jce_policy.zip
fi;



# Install libjpeg-turbo for that specific Geoserver version

if [ ! -f ./resources/libjpeg-turbo-official_1.5.3_amd64.deb ]; then \
    wget https://tenet.dl.sourceforge.net/project/libjpeg-turbo/1.5.3/libjpeg-turbo-official_1.5.3_amd64.deb -P ./resources;\
    fi; \
    cd ./resources/ && \
    dpkg -i libjpeg-turbo-official_1.5.3_amd64.deb

#Download tomcat APR
if [ ! -f ./resources/apr-1.6.3.tar.gz ]; then \
    wget -c wget  http://mirror.za.web4africa.net/apache//apr/apr-1.6.3.tar.gz \
      -P ./resources; \
    fi; \
    tar -xzf ./resources/apr-1.6.3.tar.gz -C ./resources/ && \
    cd ./resources/apr-1.6.3 && \
    touch libtoolT && ./configure && make -j 4 && make install


#Download tomcat native
if [ ! -f ./resources/tomcat-native-1.2.16-src.tar.gz ]; then \
    wget -c http://mirror.za.web4africa.net/apache/tomcat/tomcat-connectors/native/1.2.16/source/tomcat-native-1.2.16-src.tar.gz \
      -P ./resources; \
 fi; \
    tar -xzf ./resources/tomcat-native-1.2.16-src.tar.gz -C ./resources/ && \
    cd ./resources/tomcat-native-1.2.16-src/native && \
    ./configure --with-java-home=${JAVA_HOME} --with-apr=/usr/local/apr && make -j 4 && make install

# install Font files in resources/fonts if they exist
if ls ./resources/fonts/*.ttf > /dev/null 2>&1; then \
      cp -rf ./resources/fonts/*.ttf /usr/share/fonts/truetype/; \
	fi;

#Extensions
pushd /resources/plugins

# Vector tiles
wget -c https://tenet.dl.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-vectortiles-plugin.zip -O geoserver-${GS_VERSION}-vectortiles-plugin.zip
# CSS styling
wget -c https://tenet.dl.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-css-plugin.zip -O geoserver-${GS_VERSION}-css-plugin.zip

#CSW
wget -c https://tenet.dl.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-csw-plugin.zip -O geoserver-${GS_VERSION}-csw-plugin.zip
# WPS
wget -c https://tenet.dl.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-wps-plugin.zip -O geoserver-${GS_VERSION}-wps-plugin.zip
# Printing plugin
wget -c https://tenet.dl.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-printing-plugin.zip -O geoserver-${GS_VERSION}-printing-plugin.zip
#libjpeg-turbo
wget -c https://tenet.dl.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-libjpeg-turbo-plugin.zip -O geoserver-${GS_VERSION}-libjpeg-turbo-plugin.zip
#Control flow
wget -c https://sourceforge.net/projects/geoserver/files/GeoServer/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-control-flow-plugin.zip/download -O geoserver-${GS_VERSION}-control-flow-plugin.zip
#Image pyramid
wget -c https://sourceforge.net/projects/geoserver/files/GeoServer/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-pyramid-plugin.zip/download -O geoserver-${GS_VERSION}-pyramid-plugin.zip
#GDAL

#GDAL
wget -c https://sourceforge.net/projects/geoserver/files/GeoServer/${GS_VERSION}/extensions/geoserver-${GS_VERSION}-gdal-plugin.zip/download -O geoserver-${GS_VERSION}-gdal-plugin.zip


if [ ! -d gdal ];
then
    echo "Creating gdal  directory"
    mkdir -p gdal
fi


pushd ./gdal
wget -c http://demo.geo-solutions.it/share/github/imageio-ext/releases/1.1.X/1.1.15/native/gdal/gdal-data.zip
popd
wget -c http://demo.geo-solutions.it/share/github/imageio-ext/releases/1.1.X/1.1.15/native/gdal/linux/gdal192-Ubuntu12-gcc4.6.3-x86_64.tar.gz

pushd /

# Build geogig and other community modules

if  [ "$COMMUNITY_MODULES" == true ]; then
    git clone   https://github.com/geoserver/geoserver.git && \
    pushd ./geoserver && \
    git checkout ${GS_VERSION:0:5}x && \
    mvn clean install -DskipTests -f src/community/pom.xml -P communityRelease assembly:attached && \
    cp -r src/community/target/release /community-plugins && \
    pushd /community-plugins && \
    cp geoserver-${GS_VERSION:0:4}-SNAPSHOT-backup-restore-plugin.zip geoserver-${GS_VERSION:0:4}-SNAPSHOT-geogig-plugin.zip \
    geoserver-${GS_VERSION:0:4}-SNAPSHOT-mbstyle-plugin.zip geoserver-${GS_VERSION:0:4}-SNAPSHOT-mbtiles-plugin.zip /resources/plugins && \
    rm -rf /geoserver
else
    echo "Building community modules will be disabled"
fi;

pushd /


# Install Oracle JDK (and uninstall OpenJDK JRE) if the build-arg ORACLE_JDK = true or an Oracle tar.gz
# was found in /tmp/resources
if ls /var/cache/oracle-jdk8-installer/*jdk-*-linux-x64.tar.gz > /dev/null 2>&1 || [ "$ORACLE_JDK" == true ]; then \
       apt-get autoremove --purge -y openjdk-8-jre-headless && \
       echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true \
         | debconf-set-selections && \
       echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu xenial main" \
         > /etc/apt/sources.list.d/webupd8team-java.list && \
       apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EEA14886 && \
       rm -rf /var/lib/apt/lists/* && \
       apt-get update && \
       apt-get install -y oracle-java8-installer oracle-java8-set-default && \
       ln -s --force /usr/lib/jvm/java-8-oracle /usr/lib/jvm/default-java && \
       rm -rf /var/lib/apt/lists/* && \
       rm -rf /var/cache/oracle-jdk8-installer; \
       if [ -f ./resources/jce_policy.zip ]; then \
         unzip -j ./resources/jce_policy.zip -d /tmp/jce_policy && \
         mv /tmp/jce_policy/*.jar $JAVA_HOME/jre/lib/security/; \
       fi; \
    fi;
#Add JAI and ImageIO for great speedy speed.

# A little logic that will fetch the JAI and JAI ImageIO tar file if it
# is not available locally in the resources dir
 if [ ! -f ./resources/jai-1_1_3-lib-linux-amd64.tar.gz ]; then \
    wget http://download.java.net/media/jai/builds/release/1_1_3/jai-1_1_3-lib-linux-amd64.tar.gz -P ./resources;\
    fi; \
    if [ ! -f ./resources/jai_imageio-1_1-lib-linux-amd64.tar.gz ]; then \
    wget http://download.java.net/media/jai-imageio/builds/release/1.1/jai_imageio-1_1-lib-linux-amd64.tar.gz -P ./resources;\
    fi; \
    mv ./resources/jai-1_1_3-lib-linux-amd64.tar.gz ./ && \
    mv ./resources/jai_imageio-1_1-lib-linux-amd64.tar.gz ./ && \
    gunzip -c jai-1_1_3-lib-linux-amd64.tar.gz | tar xf - -C /tmp/&& \
    gunzip -c jai_imageio-1_1-lib-linux-amd64.tar.gz | tar xf - -C /tmp/ && \
    mv /tmp/jai-1_1_3/lib/*.jar $JAVA_HOME/jre/lib/ext/ && \
    mv /tmp/jai-1_1_3/lib/*.so $JAVA_HOME/jre/lib/amd64/ && \
    mv /tmp/jai_imageio-1_1/lib/*.jar $JAVA_HOME/jre/lib/ext/ && \
    mv /tmp/jai_imageio-1_1/lib/*.so $JAVA_HOME/jre/lib/amd64/ && \
    rm jai-1_1_3-lib-linux-amd64.tar.gz && \
    rm -r /tmp/jai-1_1_3 && \
    rm jai_imageio-1_1-lib-linux-amd64.tar.gz && \
    rm -r /tmp/jai_imageio-1_1
    


# A little logic that will fetch the geoserver war zip file if it
# is not available locally in the resources dir
 if [ ! -f ./resources/geoserver-${GS_VERSION}.zip ]; then \
    wget -c http://downloads.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/geoserver-${GS_VERSION}-war.zip \
      -O ./resources/geoserver-${GS_VERSION}.zip; \
    fi; \
    unzip ./resources/geoserver-${GS_VERSION}.zip -d /tmp/geoserver \
    && unzip /tmp/geoserver/geoserver.war -d ${CATALINA_HOME}/webapps/geoserver \
    && cp -r ${CATALINA_HOME}/webapps/geoserver/data/user_projections $GEOSERVER_DATA_DIR \
    && rm -rf ${CATALINA_HOME}/webapps/geoserver/data \
    && rm -rf /tmp/geoserver

# Install any plugin zip files in resources/plugins
 if ls ./resources/plugins/*.zip > /dev/null 2>&1; then \
      for p in ./resources/plugins/*.zip; do \
        unzip $p -d /tmp/gs_plugin \
        && mv /tmp/gs_plugin/*.jar ${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/ \
        && rm -rf /tmp/gs_plugin; \
      done; \
    fi; \
    if ls ./resources/plugins/*gdal*.tar.gz > /dev/null 2>&1; then \
    mkdir /usr/local/gdal_data && mkdir /usr/local/gdal_native_libs; \
    unzip ./resources/plugins/gdal/gdal-data.zip -d /usr/local/gdal_data && \
    tar xzf ./resources/plugins/gdal192-Ubuntu12-gcc4.6.3-x86_64.tar.gz -C /usr/local/gdal_native_libs; \
    fi;

# Overlay files and directories in resources/overlays if they exist
rm -f ./resources/overlays/README.txt && \
    if ls ./resources/overlays/* > /dev/null 2>&1; then \
      cp -rf ./resources/overlays/* /; \
    fi;
# Optionally remove Tomcat manager, docs, and examples
if [ "$TOMCAT_EXTRAS" == false ]; then \
    rm -rf ${CATALINA_HOME}/webapps/ROOT && \
    rm -rf ${CATALINA_HOME}/webapps/docs && \
    rm -rf ${CATALINA_HOME}/webapps/examples && \
    rm -rf ${CATALINA_HOME}/webapps/host-manager && \
    rm -rf ${CATALINA_HOME}/webapps/manager; \
  fi;

# Delete resources after installation
rm -rf ./resources

# Enable Enable CORS
sed -i -e 's/<\/web-app>//g' ${CATALINA_HOME}/webapps/geoserver/WEB-INF/web.xml
echo "<filter>
        <filter-name>cross-origin</filter-name>
        <filter-class>org.eclipse.jetty.servlets.CrossOriginFilter</filter-class>
    </filter>
    <filter-mapping>
        <filter-name>cross-origin</filter-name>
        <url-pattern>/*</url-pattern>
    </filter-mapping>
  </web-app>
  " >>${CATALINA_HOME}/webapps/geoserver/WEB-INF/web.xml


