ARG IMAGE_VERSION=2.23.0
FROM kartoza/geoserver:$IMAGE_VERSION
LABEL GeoNode Development Team

#
# Set GeoServer version and data directory
#
ENV \
    GEOSERVER_VERSION=2.23.0 \
    GEOSERVER_DATA_DIR="/geoserver_data/data" \
    DISABLE_SECURITY_FILTER=TRUE \
    PRINT_BASE_URL=http://localhost:8080/geoserver/pdf \
    TOMCAT_EXTRAS=False \
    GEONODE_PROXY_HEADERS=TRUE \
    SAMPLE_DATA=TRUE \
    RUN_AS_ROOT=TRUE

#
# Download and install GeoServer
#
RUN rm -rf /usr/local/tomcat/webapps/geoserver ;\
    cd /usr/local/tomcat/webapps \
    && wget --no-check-certificate --progress=bar:force:noscroll https://artifacts.geonode.org/geoserver/${GEOSERVER_VERSION}/geoserver.war -O geoserver.war \
    && unzip -q geoserver.war -d geoserver \
    && rm geoserver.war

# added by simonelanucara https://github.com/simonelanucara
# Optionally add JAI, ImageIO and Marlin Render for improved Geoserver performance
WORKDIR /tmp

RUN wget --no-check-certificate https://repo1.maven.org/maven2/org/postgis/postgis-jdbc/1.3.3/postgis-jdbc-1.3.3.jar -O postgis-jdbc-1.3.3.jar && \
    wget --no-check-certificate https://maven.geo-solutions.it/org/hibernatespatial/hibernate-spatial-postgis/1.1.3.2/hibernate-spatial-postgis-1.1.3.2.jar -O hibernate-spatial-postgis-1.1.3.2.jar && \
    rm /usr/local/tomcat/webapps/geoserver/WEB-INF/lib/hibernate-spatial-h2-geodb-1.1.3.2.jar && \
    mv hibernate-spatial-postgis-1.1.3.2.jar /usr/local/tomcat/webapps/geoserver/WEB-INF/lib/ && \
    mv postgis-jdbc-1.3.3.jar /usr/local/tomcat/webapps/geoserver/WEB-INF/lib/&& \
    mv "${CATALINA_HOME}"/webapps/geoserver/WEB-INF/lib/marlin-0.9.3.jar "${CATALINA_HOME}"/webapps/geoserver/WEB-INF/lib/marlin-render.jar

RUN rm -rf "${CATALINA_HOME}"/data && \
    rm -rf "${CATALINA_HOME}"/security && \
    curl  -k -L "https://artifacts.geonode.org/geoserver/${GEOSERVER_VERSION}/geonode-geoserver-ext-web-app-data.zip" --output data.zip && \
    mkdir -p /tmp/resources && \
    unzip -x -d /tmp/resources data.zip && \
    cp -r /tmp/resources/data "${CATALINA_HOME}"/ && \
    cp -r "${CATALINA_HOME}"/webapps/geoserver/data/security "${CATALINA_HOME}" && \
    rm -rf /tmp/resources
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


ENTRYPOINT ["/bin/bash", "/usr/local/tomcat/tmp/entrypoint.sh"]
