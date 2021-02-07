#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
ARG IMAGE_VERSION=jdk11-openjdk-slim-buster

ARG JAVA_HOME=/usr/local/openjdk-11

FROM tomcat:$IMAGE_VERSION

LABEL maintainer="Tim Sutton<tim@linfiniti.com>"

ARG GS_VERSION=2.18.2

ARG WAR_URL=http://downloads.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/geoserver-${GS_VERSION}-war.zip
ARG ACTIVATE_ALL_STABLE_EXTENTIONS=1
ARG ACTIVATE_ALL_COMMUNITY_EXTENTIONS=1

#Install extra fonts to use with sld font markers
RUN apt-get -y update; apt-get install -y fonts-cantarell lmodern ttf-aenigma ttf-georgewilliams ttf-bitstream-vera \
    ttf-sjfonts tv-fonts build-essential libapr1-dev libssl-dev  gdal-bin libgdal-java wget zip curl xsltproc certbot \
    certbot  cabextract

RUN wget http://ftp.br.debian.org/debian/pool/contrib/m/msttcorefonts/ttf-mscorefonts-installer_3.6_all.deb && \
    dpkg -i ttf-mscorefonts-installer_3.6_all.deb && rm ttf-mscorefonts-installer_3.6_all.deb

RUN set -e \
    export DEBIAN_FRONTEND=noninteractive \
    dpkg-divert --local --rename --add /sbin/initctl \
    && (echo "Yes, do as I say!" | apt-get remove --force-yes login) \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV \
    JAVA_HOME=${JAVA_HOME} \
    STABLE_EXTENSIONS= \
    COMMUNITY_EXTENSIONS= \
    DEBIAN_FRONTEND=noninteractive \
    GEOSERVER_DATA_DIR=/opt/geoserver/data_dir \
    GDAL_DATA=/usr/local/gdal_data \
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/gdal_native_libs:/usr/local/tomcat/native-jni-lib:/usr/lib/jni:/usr/local/apr/lib:/opt/libjpeg-turbo/lib64:/usr/lib:/usr/lib/x86_64-linux-gnu" \
    FOOTPRINTS_DATA_DIR=/opt/footprints_dir \
    GEOWEBCACHE_CACHE_DIR=/opt/geoserver/data_dir/gwc \
    ENABLE_JSONP=true \
    MAX_FILTER_RULES=20 \
    OPTIMIZE_LINE_WIDTH=false \
    SSL=false \
    TOMCAT_EXTRAS=true \
    HTTP_PORT=8080 \
    HTTP_PROXY_NAME= \
    HTTP_PROXY_PORT= \
    HTTP_REDIRECT_PORT= \
    HTTP_CONNECTION_TIMEOUT=20000 \
    HTTPS_PORT=8443 \
    HTTPS_MAX_THREADS=150 \
    HTTPS_CLIENT_AUTH= \
    HTTPS_PROXY_NAME= \
    HTTPS_PROXY_PORT= \
    JKS_FILE=letsencrypt.jks \
    JKS_KEY_PASSWORD='geoserver' \
    KEY_ALIAS=letsencrypt \
    JKS_STORE_PASSWORD='geoserver' \
    P12_FILE=letsencrypt.p12 \
    PKCS12_PASSWORD='geoserver' \
    LETSENCRYPT_CERT_DIR=/etc/letsencrypt \
    RANDFILE=${LETSENCRYPT_CERT_DIR}/.rnd \
    GEOSERVER_CSRF_DISABLED=true \
    FONTS_DIR=/opt/fonts \
    ENCODING='UTF8' \
    TIMEZONE='GMT' \
    CHARACTER_ENCODING='UTF-8' \
    # cluster env variables
    CLUSTERING=False \
    CLUSTER_DURABILITY=true \
    BROKER_URL= \
    READONLY=disabled \
    RANDOMSTRING=23bd87cfa327d47e \
    INSTANCE_STRING=ac3bcba2fa7d989678a01ef4facc4173010cd8b40d2e5f5a8d18d5f863ca976f \
    TOGGLE_MASTER=true \
    TOGGLE_SLAVE=true \
    EMBEDDED_BROKER=enabled \
    DB_BACKEND= \
    LOGIN_STATUS=on \
    WEB_INTERFACE=false


WORKDIR /scripts
RUN mkdir -p  ${GEOSERVER_DATA_DIR} ${LETSENCRYPT_CERT_DIR} ${FOOTPRINTS_DATA_DIR} ${FONTS_DIR} ${GEOWEBCACHE_CACHE_DIR}


ADD resources /tmp/resources
ADD build_data /build_data
RUN mkdir /community_plugins /stable_plugins /plugins
RUN cp /build_data/stable_plugins.txt /plugins && cp /build_data/community_plugins.txt /community_plugins && \
    cp /build_data/log4j.properties  ${CATALINA_HOME} && cp /build_data/web.xml ${CATALINA_HOME}/conf && \
    cp /build_data/letsencrypt-tomcat.xsl ${CATALINA_HOME}/conf && \
    cp /build_data/tomcat-users.xml /usr/local/tomcat/conf


ADD scripts /scripts
RUN chmod +x /scripts/*.sh
RUN /scripts/setup.sh \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


ENV \
    ## Initial Memory that Java can allocate
    INITIAL_MEMORY="2G" \
    ## Maximum Memory that Java can allocate
    MAXIMUM_MEMORY="4G" \
    XFRAME_OPTIONS="true" \
    REQUEST_TIMEOUT=60 \
    PARARELL_REQUEST=100 \
    GETMAP=10 \
    REQUEST_EXCEL=4 \
    SINGLE_USER=6 \
    GWC_REQUEST=16 \
    WPS_REQUEST=1000/d;30s \
    S3_SERVER_URL='' \
    S3_USERNAME='' \
    S3_PASSWORD='' \
    SAMPLE_DATA='FALSE'\
    GEOSERVER_FILEBROWSER_HIDEFS=false \
    TOMCAT_PASSWORD='tomcat'




EXPOSE  $HTTPS_PORT

RUN groupadd -r geoserverusers -g 10001 && \
    useradd -m -d /home/geoserveruser/ --gid 10001 -s /bin/bash -G geoserverusers geoserveruser
RUN chown -R geoserveruser:geoserverusers ${CATALINA_HOME} ${FOOTPRINTS_DATA_DIR}  \
 ${GEOSERVER_DATA_DIR} /scripts ${LETSENCRYPT_CERT_DIR} ${FONTS_DIR} /tmp/ /home/geoserveruser/ /community_plugins/ \
 /plugins

RUN chmod o+rw ${LETSENCRYPT_CERT_DIR}

USER geoserveruser
VOLUME ["${GEOSERVER_DATA_DIR}", "${LETSENCRYPT_CERT_DIR}", "${FOOTPRINTS_DATA_DIR}", "${FONTS_DIR}"]
WORKDIR ${CATALINA_HOME}

CMD ["/bin/sh", "/scripts/entrypoint.sh"]
