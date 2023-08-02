ARG IMAGE_VERSION=9.0.73-jdk11-temurin-focal
ARG JAVA_HOME=/opt/java/openjdk
FROM tomcat:$IMAGE_VERSION
LABEL GeoNode Development Team

#
# Set GeoServer version and data directory
#
ARG GS_VERSION=2.23.1
ARG WAR_URL=https://artifacts.geonode.org/geoserver/${GS_VERSION}/geoserver.war
ARG STABLE_PLUGIN_BASE_URL=https://sonik.dl.sourceforge.net
ARG DOWNLOAD_ALL_STABLE_EXTENSIONS=1
ARG DOWNLOAD_ALL_COMMUNITY_EXTENSIONS=1
ARG HTTPS_PORT=8443
ARG GEOSERVER_CORS_ENABLED=False
ARG GEOSERVER_CORS_ALLOWED_ORIGINS=*
ARG GEOSERVER_CORS_ALLOWED_METHODS=GET,POST,PUT,DELETE,HEAD,OPTIONS
ARG GEOSERVER_CORS_ALLOWED_HEADERS=*
ENV DEBIAN_FRONTEND=noninteractive

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

#
# Set GeoServer version and data directory
#
ENV \
    JAVA_HOME=${JAVA_HOME} \
    DEBIAN_FRONTEND=noninteractive \
    GEOSERVER_DATA_DIR=/geoserver_data/data \
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
    STABLE_PLUGINS_DIR=/stable_plugins \
    GEOSERVER_CORS_ENABLED=$GEOSERVER_CORS_ENABLED \
    GEOSERVER_CORS_ALLOWED_ORIGINS=$GEOSERVER_CORS_ALLOWED_ORIGINS \
    GEOSERVER_CORS_ALLOWED_METHODS=$GEOSERVER_CORS_ALLOWED_METHODS \
    GEOSERVER_CORS_ALLOWED_HEADERS=$GEOSERVER_CORS_ALLOWED_HEADERS \
    PRINT_BASE_URL=http://geoserver:8080/geoserver/pdf


# Download and install GeoServer
#
RUN apt-get update -y && apt-get install curl wget unzip -y
RUN cd /usr/local/tomcat/webapps \
    && wget --no-check-certificate --progress=bar:force:noscroll https://artifacts.geonode.org/geoserver/${GS_VERSION}/geoserver.war -O geoserver.war \
    && unzip -q geoserver.war -d geoserver \
    && rm geoserver.war \
    && mkdir -p $GEOSERVER_DATA_DIR

VOLUME $GEOSERVER_DATA_DIR

# added by simonelanucara https://github.com/simonelanucara
# Optionally add JAI, ImageIO and Marlin Render for improved Geoserver performance
WORKDIR /tmp

RUN wget --no-check-certificate https://repo1.maven.org/maven2/org/postgis/postgis-jdbc/1.3.3/postgis-jdbc-1.3.3.jar -O postgis-jdbc-1.3.3.jar && \
    wget --no-check-certificate https://maven.geo-solutions.it/org/hibernatespatial/hibernate-spatial-postgis/1.1.3.2/hibernate-spatial-postgis-1.1.3.2.jar -O hibernate-spatial-postgis-1.1.3.2.jar && \
    rm /usr/local/tomcat/webapps/geoserver/WEB-INF/lib/hibernate-spatial-h2-geodb-1.1.3.2.jar && \
    mv hibernate-spatial-postgis-1.1.3.2.jar /usr/local/tomcat/webapps/geoserver/WEB-INF/lib/ && \
    mv postgis-jdbc-1.3.3.jar /usr/local/tomcat/webapps/geoserver/WEB-INF/lib/

ADD build_data /build_data
ADD scripts /scripts

RUN echo $GS_VERSION > /scripts/geoserver_version.txt ;\
    chmod +x /scripts/*.sh;/scripts/setup.sh \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


###########docker host###############
# Set DOCKERHOST variable if DOCKER_HOST exists
ARG DOCKERHOST=${DOCKERHOST}
# for debugging
RUN echo -n #1===>DOCKERHOST=${DOCKERHOST}
#
ENV DOCKERHOST ${DOCKERHOST}
# for debugging
RUN echo -n #2===>DOCKERHOST=${DOCKERHOST}

###########docker host ip#############
# Set GEONODE_HOST_IP address if it exists
ARG GEONODE_HOST_IP=${GEONODE_HOST_IP}
# for debugging
RUN echo -n #1===>GEONODE_HOST_IP=${GEONODE_HOST_IP}
#
ENV GEONODE_HOST_IP ${GEONODE_HOST_IP}
# for debugging
RUN echo -n #2===>GEONODE_HOST_IP=${GEONODE_HOST_IP}
# If empty set DOCKER_HOST_IP to GEONODE_HOST_IP
ENV DOCKER_HOST_IP=${DOCKER_HOST_IP:-${GEONODE_HOST_IP}}
# for debugging
RUN echo -n #1===>DOCKER_HOST_IP=${DOCKER_HOST_IP}
# Trying to set the value of DOCKER_HOST_IP from DOCKER_HOST
RUN if ! [ -z ${DOCKER_HOST_IP} ]; \
    then echo export DOCKER_HOST_IP=${DOCKERHOST} | \
    sed 's/tcp:\/\/\([^:]*\).*/\1/' >> /root/.bashrc; \
    else echo "DOCKER_HOST_IP is already set!"; fi
# for debugging
RUN echo -n #2===>DOCKER_HOST_IP=${DOCKER_HOST_IP}

# Set WEBSERVER public port
ARG PUBLIC_PORT=${PUBLIC_PORT}
# for debugging
RUN echo -n #1===>PUBLIC_PORT=${PUBLIC_PORT}
#
ENV PUBLIC_PORT=${PUBLIC_PORT}
# for debugging
RUN echo -n #2===>PUBLIC_PORT=${PUBLIC_PORT}

# set nginx base url for geoserver
RUN echo export NGINX_BASE_URL=http://${NGINX_HOST}:${NGINX_PORT}/ | \
    sed 's/tcp:\/\/\([^:]*\).*/\1/' >> /root/.bashrc

# copy the script and perform the run of scripts from entrypoint.sh
ADD  geonode_scripts /usr/local/tomcat/tmp
WORKDIR /usr/local/tomcat/tmp
COPY ./templates /templates

RUN apt-get update \
    && apt-get install -y procps less \
    && apt-get install -y python3 python3-pip python3-dev \
    && chmod +x /usr/local/tomcat/tmp/*.sh \
    && pip3 install pip --upgrade \
    && pip3 install -r requirements.txt \
    && chmod +x /usr/local/tomcat/tmp/*.py

RUN pip install j2cli

#ENV JAVA_OPTS="-Djava.awt.headless=true -XX:+UnlockDiagnosticVMOptions -XX:+LogVMOutput -XX:LogFile=/var/log/jvm.log -XX:MaxPermSize=512m -XX:PermSize=256m -Xms512m -Xmx2048m -XX:+UseConcMarkSweepGC -XX:ParallelGCThreads=4 -Dfile.encoding=UTF8 -Djavax.servlet.request.encoding=UTF-8 -Djavax.servlet.response.encoding=UTF-8 -Duser.timezone=GMT -Dorg.geotools.shapefile.datetime=false -DGEOSERVER_CSRF_DISABLED=true -DPRINT_BASE_URL=http://geoserver:8080/geoserver/pdf -Xbootclasspath/a:/usr/local/tomcat/webapps/geoserver/WEB-INF/lib/marlin-render.jar -Dsun.java2d.renderer=org.marlin.pisces.MarlinRenderingEngine"

CMD ["/usr/local/tomcat/tmp/entrypoint.sh"]
