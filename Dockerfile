#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
ARG IMAGE_VERSION=9-jre11-slim


FROM tomcat:$IMAGE_VERSION

LABEL maintainer="Tim Sutton<tim@linfiniti.com>"


ARG GS_VERSION=2.16.2


## Would you like to keep default Tomcat webapps
ARG TOMCAT_EXTRAS=true

ARG WAR_URL=http://downloads.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/geoserver-${GS_VERSION}-war.zip
ARG STABLE_PLUGIN_URL=https://liquidtelecom.dl.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/extensions

#Install extra fonts to use with sld font markers
RUN apt-get -y update; apt-get install -y fonts-cantarell lmodern ttf-aenigma ttf-georgewilliams ttf-bitstream-vera \
    ttf-sjfonts tv-fonts build-essential libapr1-dev libssl-dev  gdal-bin libgdal-java wget zip curl xsltproc certbot \
    certbot

RUN set -e \
    export DEBIAN_FRONTEND=noninteractive \
    dpkg-divert --local --rename --add /sbin/initctl \
    # Set JAVA_HOME to /usr/lib/jvm/default-java and link it to OpenJDK installation
    && ln -s /usr/lib/jvm/java-11-openjdk-amd64 /usr/lib/jvm/default-java \
    && (echo "Yes, do as I say!" | apt-get remove --force-yes login) \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV \
    JAVA_HOME=/usr/lib/jvm/default-java \
    STABLE_EXTENSIONS='' \
    COMMUNITY_EXTENSIONS='' \
    DEBIAN_FRONTEND=noninteractive \
    GEOSERVER_DATA_DIR=/opt/geoserver/data_dir \
    GDAL_DATA=/usr/local/gdal_data \
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/apr/lib:/opt/libjpeg-turbo/lib64:/usr/lib:/usr/lib/x86_64-linux-gnu" \
    FOOTPRINTS_DATA_DIR=/opt/footprints_dir \
    GEOWEBCACHE_CACHE_DIR=/opt/geoserver/data_dir/gwc \
    ENABLE_JSONP=true \
    MAX_FILTER_RULES=20 \
    OPTIMIZE_LINE_WIDTH=false \
    SSL=false \
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
    FONTS_DIR=/opt/fonts



WORKDIR /scripts


RUN mkdir -p  ${GEOSERVER_DATA_DIR} ${LETSENCRYPT_CERT_DIR} ${FOOTPRINTS_DATA_DIR} ${FONTS_DIR}


ADD resources /tmp/resources
ADD build_data/stable_plugins.txt /plugins/stable_plugins.txt
ADD build_data/community_plugins.txt /community_plugins/community_plugins.txt
ADD build_data/log4j.properties  ${CATALINA_HOME}/log4j.properties
ADD build_data/web.xml ${CATALINA_HOME}/conf/web.xml
ADD scripts /scripts
ADD build_data/letsencrypt-tomcat.xsl ${CATALINA_HOME}/conf/letsencrypt-tomcat.xsl
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
    GEOSERVER_FILEBROWSER_HIDEFS=false




EXPOSE  $HTTPS_PORT

RUN groupadd -r geoserverusers -g 10001 && \
    useradd -M -u 10000 -g geoserverusers geoserveruser
RUN chown -R geoserveruser:geoserverusers /usr/local/tomcat ${FOOTPRINTS_DATA_DIR}  \
 ${GEOSERVER_DATA_DIR} /scripts ${LETSENCRYPT_CERT_DIR} ${FONTS_DIR} /tmp/

RUN chmod o+rw ${LETSENCRYPT_CERT_DIR}

USER geoserveruser
WORKDIR ${CATALINA_HOME}

CMD ["/bin/sh", "/scripts/entrypoint.sh"]
