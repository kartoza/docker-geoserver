
#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
ARG IMAGE_VERSION=9.0.109-jdk17-temurin-noble
ARG JAVA_HOME=/opt/java/openjdk
#TODO we need a way to predetermine the gdal version in the tomcat image so as to match it
ARG GDAL_VERSION=3.8.4
ARG TARGETARCH

FROM --platform=$BUILDPLATFORM ghcr.io/osgeo/gdal:ubuntu-full-${GDAL_VERSION} AS gdal-builder

##############################################################################
# Plugin downloader                                                          #
##############################################################################
# This container pulls in lists of plugins from
# build_data/{required,stable,community}_plugins.txt, and then builds a curl
# configuration file to fetch everything in each list, allowing HTTPS
# connection re-use.
#
# By comparison, calling curl for each URL individually means setting up a new
# HTTPS connection for each URL, which is at least 3 network round-trips
# before we've even sent our HTTP request!
#
# Being a separate stage, docker buildx can run this part in parallel with the
# rest of the build, and it can leverage caches to improve re-build times when
# not changing any plugins (saving ~460 MiB of downloads).

# Use $BUILDPLATFORM because plugin archives are architecture-neutral, and use
# alpine because it's smaller.

FROM --platform=$BUILDPLATFORM python:alpine3.20 AS geoserver-plugin-downloader
ARG GS_VERSION=2.28.0
ARG STABLE_PLUGIN_BASE_URL=https://sourceforge.net/projects/geoserver/files/GeoServer
ARG WAR_URL=https://downloads.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/geoserver-${GS_VERSION}-war.zip
ENV OTEL_VERSION=v2.17.1
ENV JMX_PROMETHEUS_VERSION=1.0.1
ENV LOG4J_VERSION=2.24.3

RUN apk update && apk add curl py3-pip
RUN pip3 install beautifulsoup4 requests

WORKDIR /work
ADD \
    build_data/community_plugins.py \
    build_data/stable_plugins.py \
    build_data/extensions.sh \
    build_data/required_plugins.txt \
    build_data/plugin_download.sh \
    /work/

RUN echo ${GS_VERSION} > /tmp/pass.txt && chmod 0755 /work/extensions.sh && /work/extensions.sh

RUN /work/plugin_download.sh

##############################################################################
# Production stage                                                           #
##############################################################################
FROM tomcat:$IMAGE_VERSION AS geoserver-prod

LABEL maintainer="Tim Sutton<tim@linfiniti.com>"
ARG GS_VERSION=2.28.0
ARG STABLE_PLUGIN_BASE_URL=https://sourceforge.net/projects/geoserver/files/GeoServer
ARG HTTPS_PORT=8443
ARG GDAL_LIBS_PATH="/usr/lib/x86_64-linux-gnu"
ENV DEBIAN_FRONTEND=noninteractive
ENV OTEL_SERVICE_NAME=geoserver

#Install extra fonts to use with sld font markers
RUN set -eux; \
    apt-get update; \
    apt-get -y --no-install-recommends install \
        locales gnupg2 ca-certificates software-properties-common  iputils-ping \
        apt-transport-https  fonts-cantarell fonts-liberation lmodern fonts-aenigma \
        ttf-bitstream-vera ttf-sjfonts tv-fonts libapr1-dev libssl-dev git \
        zip unzip curl xsltproc certbot  cabextract gettext postgresql-client figlet gosu gdal-bin; \
      dpkg-divert --local --rename --add /sbin/initctl \
      && apt-get clean \
      && rm -rf /var/lib/apt/lists/*; \
      # verify that the binary works
	  gosu nobody true

# copy gdal java bindings
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        GDAL_LIBS_PATH="/usr/lib/x86_64-linux-gnu"; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
        GDAL_LIBS_PATH="/usr/lib/aarch64-linux-gnu"; \
    fi

COPY --from=gdal-builder /usr/share/java/ /usr/share/java/
COPY --from=gdal-builder ${GDAL_LIBS_PATH}/jni/ ${GDAL_LIBS_PATH}/jni/

ENV \
    JAVA_HOME=${JAVA_HOME} \
    DEBIAN_FRONTEND=noninteractive \
    GEOSERVER_DATA_DIR=/opt/geoserver/data_dir \
    GDAL_DATA=/usr/share/gdal \
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/tomcat/native-jni-lib:/usr/lib/jni:/usr/local/apr/lib:/opt/libjpeg-turbo/lib64:/usr/lib:${GDAL_LIBS_PATH}:${GDAL_LIBS_PATH}/jni/" \
    FOOTPRINTS_DATA_DIR=/opt/footprints_dir \
    GEOWEBCACHE_CACHE_DIR=/opt/geoserver/data_dir/gwc \
    CERT_DIR=/etc/certs \
    RANDFILE=/etc/certs/.rnd \
    FONTS_DIR=/opt/fonts \
    GEOSERVER_HOME=/geoserver \
    EXTRA_CONFIG_DIR=/settings \
    COMMUNITY_PLUGINS_DIR=/community_plugins  \
    STABLE_PLUGINS_DIR=/stable_plugins \
    REQUIRED_PLUGINS_DIR=/required_plugins \
    OTEL_DIR=/otel \
    JMX_DIR=/jmx 


WORKDIR /scripts
ADD resources /tmp/resources
ADD build_data /build_data
ADD scripts /scripts

RUN mkdir -p ${OTEL_DIR} \
    && mkdir -p ${JMX_DIR} 

# copy plugins
COPY --from=geoserver-plugin-downloader /work/required_plugins/*.zip ${REQUIRED_PLUGINS_DIR}/
COPY --from=geoserver-plugin-downloader /work/required_plugins/*.jar ${REQUIRED_PLUGINS_DIR}/
COPY --from=geoserver-plugin-downloader /work/required_plugins.txt ${REQUIRED_PLUGINS_DIR}/
COPY --from=geoserver-plugin-downloader /work/stable_plugins/*.zip ${STABLE_PLUGINS_DIR}/
COPY --from=geoserver-plugin-downloader /work/community_plugins/*.zip ${COMMUNITY_PLUGINS_DIR}/
COPY --from=geoserver-plugin-downloader /work/geoserver_war/geoserver.* ${REQUIRED_PLUGINS_DIR}/
COPY --from=geoserver-plugin-downloader /work/community_plugins.txt ${COMMUNITY_PLUGINS_DIR}/
COPY --from=geoserver-plugin-downloader /work/stable_plugins.txt ${STABLE_PLUGINS_DIR}/

# copy telemetry jars
COPY --from=geoserver-plugin-downloader /work/telemetry/opentelemetry-javaagent.jar ${OTEL_DIR}/opentelemetry-javaagent.jar
COPY --from=geoserver-plugin-downloader /work/telemetry/log4j-layout-template-json.jar "${REQUIRED_PLUGINS_DIR}"/log4j-layout-template-json.jar
COPY --from=geoserver-plugin-downloader /work/telemetry/jmx_prometheus_javaagent.jar ${JMX_DIR}/jmx_prometheus_javaagent.jar
COPY --from=geoserver-plugin-downloader /work/telemetry/jmx_config.yaml ${JMX_DIR}/config.yaml

RUN ldconfig


RUN echo ${GS_VERSION} > /scripts/geoserver_version.txt && echo ${STABLE_PLUGIN_BASE_URL} > /scripts/geoserver_gs_url.txt ;\
    chmod +x /scripts/*.sh;/scripts/setup.sh \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


EXPOSE  ${HTTPS_PORT}


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

RUN pip3 install -r /lib/utils/requirements.txt --break-system-packages
