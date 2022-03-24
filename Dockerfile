#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
ARG IMAGE_VERSION=9.0-jdk11-openjdk-slim-buster
ARG JAVA_HOME=/usr/local/openjdk-11
FROM tomcat:$IMAGE_VERSION

LABEL maintainer="Tim Sutton<tim@linfiniti.com>"
ARG GS_VERSION=2.20.3
ARG WAR_URL=https://downloads.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/geoserver-${GS_VERSION}-war.zip
ARG STABLE_PLUGIN_BASE_URL=https://liquidtelecom.dl.sourceforge.net
ARG DOWNLOAD_ALL_STABLE_EXTENSIONS=1
ARG DOWNLOAD_ALL_COMMUNITY_EXTENSIONS=1
ARG GEOSERVER_UID=1000
ARG GEOSERVER_GID=10001
ARG USER=geoserveruser
ARG GROUP_NAME=geoserverusers
ARG HTTPS_PORT=8443

#Install extra fonts to use with sld font markers
RUN apt-get -y update; apt-get -y --no-install-recommends install fonts-cantarell lmodern ttf-aenigma \
    ttf-georgewilliams ttf-bitstream-vera ttf-sjfonts tv-fonts  libapr1-dev libssl-dev  \
    gdal-bin libgdal-java wget zip unzip curl xsltproc certbot  cabextract gettext postgresql-client figlet

RUN set -e \
    export DEBIAN_FRONTEND=noninteractive \
    dpkg-divert --local --rename --add /sbin/initctl \
    && (echo "Yes, do as I say!" | apt-get remove --force-yes login) \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV \
    JAVA_HOME=${JAVA_HOME} \
    DEBIAN_FRONTEND=noninteractive \
    GEOSERVER_DATA_DIR=/opt/geoserver/data_dir \
    GDAL_DATA=/usr/local/gdal_data \
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/gdal_native_libs:/usr/local/tomcat/native-jni-lib:/usr/lib/jni:/usr/local/apr/lib:/opt/libjpeg-turbo/lib64:/usr/lib:/usr/lib/x86_64-linux-gnu" \
    FOOTPRINTS_DATA_DIR=/opt/footprints_dir \
    GEOWEBCACHE_CACHE_DIR=/opt/geoserver/data_dir/gwc \
    CERT_DIR=/etc/certs \
    RANDFILE=/etc/certs/.rnd \
    FONTS_DIR=/opt/fonts \
    GEOSERVER_HOME=/geoserver \
    EXTRA_CONFIG_DIR=/settings


WORKDIR /scripts
RUN groupadd -r ${GROUP_NAME} -g ${GEOSERVER_GID} && \
    useradd -m -d /home/${USER}/ -u ${GEOSERVER_UID} --gid ${GEOSERVER_GID} -s /bin/bash -G ${GROUP_NAME} ${USER}
RUN mkdir -p  ${GEOSERVER_DATA_DIR} ${CERT_DIR} ${FOOTPRINTS_DATA_DIR} ${FONTS_DIR} \
             ${GEOWEBCACHE_CACHE_DIR} ${GEOSERVER_HOME} ${EXTRA_CONFIG_DIR} /community_plugins /stable_plugins \
           /plugins /geo_data

ADD resources /tmp/resources
ADD build_data /build_data
RUN cp /build_data/stable_plugins.txt /plugins && cp /build_data/community_plugins.txt /community_plugins && \
    cp /build_data/letsencrypt-tomcat.xsl ${CATALINA_HOME}/conf/ssl-tomcat.xsl

ADD scripts /scripts
RUN echo $GS_VERSION > /scripts/geoserver_version.txt
RUN chmod +x /scripts/*.sh;/scripts/setup.sh \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*;chown -R ${USER}:${GROUP_NAME} \
    ${CATALINA_HOME} ${FOOTPRINTS_DATA_DIR} ${GEOSERVER_DATA_DIR} /scripts ${CERT_DIR} ${FONTS_DIR} \
    /tmp/ /home/${USER}/ /community_plugins/ /plugins ${GEOSERVER_HOME} ${EXTRA_CONFIG_DIR} \
    /usr/share/fonts/ /geo_data;chmod o+rw ${CERT_DIR}


EXPOSE  $HTTPS_PORT


USER ${GEOSERVER_UID}
RUN echo 'figlet -t "Kartoza Docker GeoServer"' >> ~/.bashrc

WORKDIR ${GEOSERVER_HOME}

CMD ["/bin/bash", "/scripts/entrypoint.sh"]
