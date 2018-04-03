#!/usr/bin/env bash
# Download geoserver extensions and other resources
pushd resources
#Java
#Webupd8
#wget -c https://launchpad.net/~webupd8team/+archive/ubuntu/java/+files/oracle-java8-installer_8u101+8u101arm-1~webupd8~2.tar.xz
#Oracle
#wget -c http://download.oracle.com/otn-pub/java/jdk/8u112-b15/jdk-8u112-linux-x64.tar.gz
wget -c --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/8u161-b12/2f38c3b165be4555a1fa6e98c45e0808/jre-8u161-linux-x64.tar.gz
#Policy
wget -c --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip -O jce_policy.zip

#JAI
wget -c http://download.java.net/media/jai/builds/release/1_1_3/jai-1_1_3-lib-linux-amd64.tar.gz

#JAI Image i/o
wget -c  http://download.java.net/media/jai-imageio/builds/release/1.1/jai_imageio-1_1-lib-linux-amd64.tar.gz

#Geoserver
VERSION=2.13.0

wget -c http://sourceforge.net/projects/geoserver/files/GeoServer/$VERSION/geoserver-$VERSION-war.zip -O geoserver-${VERSION}.zip

# Download libjpeg-turbo
wget -c https://tenet.dl.sourceforge.net/project/libjpeg-turbo/1.5.3/libjpeg-turbo-official_1.5.3_amd64.deb

#Download tomcat APR
wget -c http://mirror.za.web4africa.net/apache//apr/apr-1.6.3.tar.gz

#Download tomcat native
wget -c http://mirror.za.web4africa.net/apache/tomcat/tomcat-connectors/native/1.2.16/source/tomcat-native-1.2.16-src.tar.gz


# Build geogig and other community modules

git clone --depth 1 -b 2.13.x git@github.com:geoserver/geoserver.git
popd geoserver
mvn clean install -DskipTests -f src/community/pom.xml -P communityRelease assembly:attached
# choose which plugins you need to add to plugins folder
cp src/community/target/release/
cp geoserver-2.13-SNAPSHOT-backup-restore-plugin.zip geoserver-2.13-SNAPSHOT-geogig-plugin.zip \
 geoserver-2.13-SNAPSHOT-mbstyle-plugin.zip geoserver-2.13-SNAPSHOT-mbtiles-plugin.zip plugins
popd

pushd plugins
#Extensions

# Vector tiles
wget -c https://tenet.dl.sourceforge.net/project/geoserver/GeoServer/$VERSION/extensions/geoserver-$VERSION-vectortiles-plugin.zip -O geoserver-$VERSION-vectortiles-plugin.zip
# CSS styling
wget -c https://tenet.dl.sourceforge.net/project/geoserver/GeoServer/$VERSION/extensions/geoserver-$VERSION-css-plugin.zip -O geoserver-$VERSION-css-plugin.zip

#CSW
wget -c https://tenet.dl.sourceforge.net/project/geoserver/GeoServer/$VERSION/extensions/geoserver-$VERSION-csw-plugin.zip -O geoserver-$VERSION-csw-plugin.zip
# WPS
wget -c https://tenet.dl.sourceforge.net/project/geoserver/GeoServer/$VERSION/extensions/geoserver-$VERSION-wps-plugin.zip -O geoserver-$VERSION-wps-plugin.zip
# Printing plugin
wget -c https://tenet.dl.sourceforge.net/project/geoserver/GeoServer/$VERSION/extensions/geoserver-$VERSION-printing-plugin.zip -O geoserver-$VERSION-printing-plugin.zip
#libjpeg-turbo
wget -c https://tenet.dl.sourceforge.net/project/geoserver/GeoServer/$VERSION/extensions/geoserver-$VERSION-libjpeg-turbo-plugin.zip -O geoserver-$VERSION-libjpeg-turbo-plugin.zip
#Control flow
wget -c https://sourceforge.net/projects/geoserver/files/GeoServer/$VERSION/extensions/geoserver-$VERSION-control-flow-plugin.zip/download -O geoserver-$VERSION-control-flow-plugin.zip
#Image pyramid
wget -c https://sourceforge.net/projects/geoserver/files/GeoServer/$VERSION/extensions/geoserver-$VERSION-pyramid-plugin.zip/download -O geoserver-$VERSION-pyramid-plugin.zip
#GDAL
wget -c https://sourceforge.net/projects/geoserver/files/GeoServer/$VERSION/extensions/geoserver-$VERSION-gdal-plugin.zip/download -O geoserver-$VERSION-gdal-plugin.zip
mkdir gdal
pushd gdal
wget -c http://demo.geo-solutions.it/share/github/imageio-ext/releases/1.1.X/1.1.15/native/gdal/gdal-data.zip
popd
wget -c http://demo.geo-solutions.it/share/github/imageio-ext/releases/1.1.X/1.1.15/native/gdal/linux/gdal192-Ubuntu12-gcc4.6.3-x86_64.tar.gz

popd
popd
