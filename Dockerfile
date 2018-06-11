#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
FROM tomcat:9-jre8
MAINTAINER Tim Sutton<tim@linfiniti.com>

RUN  export DEBIAN_FRONTEND=noninteractive
ENV  DEBIAN_FRONTEND noninteractive
RUN  dpkg-divert --local --rename --add /sbin/initctl


RUN apt-get -y update

#Install extra fonts to use with sld font markers
RUN apt-get install -y  fonts-cantarell lmodern ttf-aenigma ttf-georgewilliams ttf-bitstream-vera ttf-sjfonts tv-fonts \
    build-essential libapr1-dev libssl-dev default-jdk
#-------------Application Specific Stuff ----------------------------------------------------

ARG GS_VERSION=2.13.1
ENV GEOSERVER_DATA_DIR /opt/geoserver/data_dir
ENV ENABLE_JSONP true
ENV MAX_FILTER_RULES 20
ENV OPTIMIZE_LINE_WIDTH false
ENV GEOWEBCACHE_CACHE_DIR /opt/geoserver/data_dir/gwc
ENV GEOSERVER_OPTS "-Djava.awt.headless=true -server -Xms2G -Xmx4G -Xrs -XX:PerfDataSamplingInterval=500 \
 -Dorg.geotools.referencing.forceXY=true -XX:SoftRefLRUPolicyMSPerMB=36000 -XX:+UseParallelGC -XX:NewRatio=2 \
 -XX:+CMSClassUnloadingEnabled"
#-XX:+UseConcMarkSweepGC use this rather than parallel GC?
ENV JAVA_OPTS "$JAVA_OPTS $GEOSERVER_OPTS"
ENV GDAL_DATA /usr/local/gdal_data
ENV LD_LIBRARY_PATH /usr/local/gdal_native_libs:/usr/local/apr/lib:/opt/libjpeg-turbo/lib64
ENV GEOSERVER_LOG_LOCATION /opt/geoserver/data_dir/logs/geoserver.log
ADD logs $GEOSERVER_DATA_DIR
ENV FOOTPRINTS_DATA_DIR /opt/footprints_dir
# Unset Java related ENVs since they may change with Oracle JDK
ENV JAVA_VERSION=
ENV JAVA_DEBIAN_VERSION=
# Set JAVA_HOME to /usr/lib/jvm/default-java and link it to OpenJDK installation
RUN ln -s /usr/lib/jvm/java-8-openjdk-amd64 /usr/lib/jvm/default-java
ENV JAVA_HOME /usr/lib/jvm/default-java
ARG ORACLE_JDK=false
ARG TOMCAT_EXTRAS=true
ARG COMMUNITY_MODULES=true
ARG GEONODE=false
WORKDIR /tmp/
ADD resources /tmp/resources
ADD scripts/setup.sh /
RUN chmod +x /*.sh
RUN /setup.sh
ADD controlflow.properties $GEOSERVER_DATA_DIR
ADD sqljdbc4-4.0.jar $CATALINA_HOME/webapps/geoserver/WEB-INF/lib/
# copy the script and perform the run of scripts from entrypoint.sh
ADD geonode  /usr/local/tomcat/tmp
WORKDIR /usr/local/tomcat/tmp
ADD scripts/setup-geonode.sh /usr/local/tomcat/tmp/setup-geonode.sh
RUN chmod +x /usr/local/tomcat/tmp/*.sh
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

RUN if (($GEONODE == true )); then \
      /bin/bash ./setup-geonode.sh; \
fi;
CMD ["/usr/local/tomcat/tmp/entrypoint.sh"]

