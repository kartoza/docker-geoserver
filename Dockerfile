##############################################################################
# Production stage                                                           #
##############################################################################

#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
ARG IMAGE_VERSION=9.0.73-jdk11-temurin-focal
ARG JAVA_HOME=/opt/java/openjdk
FROM tomcat:$IMAGE_VERSION AS geoserver-prod

LABEL maintainer="Tim Sutton<tim@linfiniti.com>"
ARG GS_VERSION=2.23.2
ARG WAR_URL=https://downloads.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/geoserver-${GS_VERSION}-war.zip
ARG STABLE_PLUGIN_BASE_URL=https://sourceforge.net/projects/geoserver/files/GeoServer
ARG DOWNLOAD_ALL_STABLE_EXTENSIONS=1
ARG DOWNLOAD_ALL_COMMUNITY_EXTENSIONS=1
ARG HTTPS_PORT=8443
ENV DEBIAN_FRONTEND=noninteractive
#Install extra fonts to use with sld font markers
RUN set -eux; \
    apt-get update; \
    apt-get -y --no-install-recommends install \
        locales gnupg2 wget ca-certificates rpl pwgen software-properties-common  iputils-ping \
        apt-transport-https curl gettext fonts-cantarell lmodern ttf-aenigma \
        ttf-bitstream-vera ttf-sjfonts tv-fonts  libapr1-dev libssl-dev  \
        wget zip unzip curl xsltproc certbot  cabextract gettext postgresql-client figlet gosu gdal-bin libgdal-java; \
      dpkg-divert --local --rename --add /sbin/initctl \
      && (echo "Yes, do as I say!" | apt-get remove --force-yes login) \
      && apt-get clean \
      && rm -rf /var/lib/apt/lists/*; \
      # verify that the binary works
	  gosu nobody true


ENV \
    JAVA_HOME=${JAVA_HOME} \
    DEBIAN_FRONTEND=noninteractive \
    GEOSERVER_DATA_DIR=/opt/geoserver/data_dir \
    GDAL_DATA=/usr/share/gdal \
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/tomcat/native-jni-lib:/usr/lib/jni:/usr/local/apr/lib:/opt/libjpeg-turbo/lib64:/usr/lib:/usr/lib/x86_64-linux-gnu" \
    FOOTPRINTS_DATA_DIR=/opt/footprints_dir \
    GEOWEBCACHE_CACHE_DIR=/opt/geoserver/data_dir/gwc \
    CERT_DIR=/etc/certs \
    RANDFILE=/etc/certs/.rnd \
    FONTS_DIR=/opt/fonts \
    GEOSERVER_HOME=/geoserver \
    EXTRA_CONFIG_DIR=/settings \
    COMMUNITY_PLUGINS_DIR=/community_plugins  \
    STABLE_PLUGINS_DIR=/stable_plugins


WORKDIR /scripts
ADD resources /tmp/resources
ADD build_data /build_data
ADD scripts /scripts

RUN echo $GS_VERSION > /scripts/geoserver_version.txt && echo $STABLE_PLUGIN_BASE_URL > /scripts/geoserver_gs_url.txt ;\
    chmod +x /scripts/*.sh;/scripts/setup.sh \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


EXPOSE  $HTTPS_PORT


RUN echo 'figlet -t "Kartoza Docker GeoServer"' >> ~/.bashrc

WORKDIR ${GEOSERVER_HOME}

ENTRYPOINT ["/bin/bash", "/scripts/entrypoint.sh"]

##############################################################################
# Testing Stage                                                           #
##############################################################################
FROM geoserver-prod AS geoserver-test

COPY ./scenario_tests/utils/requirements.txt /lib/utils/requirements.txt

RUN set -eux \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get -y --no-install-recommends install python3-pip procps \
    && apt-get -y --purge autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install -r /lib/utils/requirements.txt;pip3 install numpy --upgrade
