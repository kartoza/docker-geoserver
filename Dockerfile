#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
ARG IMAGE_VERSION=8.0-jre8

FROM tomcat:$IMAGE_VERSION

MAINTAINER Tim Sutton<tim@linfiniti.com>

## The Geoserver version
ARG GS_VERSION=2.15.0

## Would you like to use Oracle JDK
ARG ORACLE_JDK=false

## Would you like to keep default Tomcat webapps
ARG TOMCAT_EXTRAS=true

ARG WAR_URL=http://downloads.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/geoserver-${GS_VERSION}-war.zip
## Would you like to install community modules
ARG COMMUNITY_MODULES=true

## Maximum Memory that Java can allocate
ARG MAXIMUM_MEMORY="4G"

## Initial Memory that Java can allocate
ARG INITIAL_MEMORY="2G"

RUN set -e \
    export DEBIAN_FRONTEND=noninteractive \
    dpkg-divert --local --rename --add /sbin/initctl \
    apt-get -y update \
    #Install extra fonts to use with sld font markers
    apt-get install -y fonts-cantarell lmodern ttf-aenigma ttf-georgewilliams ttf-bitstream-vera ttf-sjfonts tv-fonts \
        build-essential libapr1-dev libssl-dev default-jdk \
    # Set JAVA_HOME to /usr/lib/jvm/default-java and link it to OpenJDK installation
    && ln -s /usr/lib/jvm/java-8-openjdk-amd64 /usr/lib/jvm/default-java \
    && (echo "Yes, do as I say!" | apt-get remove --force-yes login) \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV \
    JAVA_HOME=/usr/lib/jvm/default-java \
    DEBIAN_FRONTEND=noninteractive \
    GEOSERVER_DATA_DIR=/opt/geoserver/data_dir \
    GDAL_DATA=/usr/local/gdal_data \
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/gdal_native_libs:/usr/local/apr/lib:/opt/libjpeg-turbo/lib64" \
    FOOTPRINTS_DATA_DIR=/opt/footprints_dir \
    GEOWEBCACHE_CACHE_DIR=/opt/geoserver/data_dir/gwc \
    ENABLE_JSONP=true \
    MAX_FILTER_RULES=20 \
    OPTIMIZE_LINE_WIDTH=false \
    GEOSERVER_OPTS="-Djava.awt.headless=true -server -Xms${INITIAL_MEMORY} -Xmx${MAXIMUM_MEMORY} -Xrs -XX:PerfDataSamplingInterval=500 \
       -Dorg.geotools.referencing.forceXY=true -XX:SoftRefLRUPolicyMSPerMB=36000 -XX:+UseParallelGC -XX:NewRatio=2 \
       -XX:+CMSClassUnloadingEnabled -Dfile.encoding=UTF8 -Duser.timezone=GMT -Djavax.servlet.request.encoding=UTF-8 \
       -Djavax.servlet.response.encoding=UTF-8 -Duser.timezone=GMT -Dorg.geotools.shapefile.datetime=true \
       -Dorg.geotools.shapefile.datetime=true -Ds3.properties.location=/opt/geoserver/data_dir/s3.properties " \
       #-XX:+UseConcMarkSweepGC use this rather than parallel GC?
    ## Unset Java related ENVs since they may change with Oracle JDK
    JAVA_VERSION= \
    JAVA_DEBIAN_VERSION= 

WORKDIR /scripts
RUN mkdir -p ${GEOSERVER_DATA_DIR}


ADD resources /tmp/resources
ADD scripts /scripts
RUN chmod +x /scripts/*.sh
ADD scripts/controlflow.properties $GEOSERVER_DATA_DIR
ADD scripts/sqljdbc4-4.0.jar $CATALINA_HOME/webapps/geoserver/WEB-INF/lib/

RUN /scripts/setup.sh \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*  \
    && dpkg --remove --force-depends  unzip



CMD ["/scripts/entrypoint.sh"]