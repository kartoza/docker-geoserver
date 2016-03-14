#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
FROM tomcat:8.0
MAINTAINER Tim Sutton<tim@linfiniti.com>

RUN  export DEBIAN_FRONTEND=noninteractive
ENV  DEBIAN_FRONTEND noninteractive
RUN  dpkg-divert --local --rename --add /sbin/initctl
#RUN  ln -s /bin/true /sbin/initctl

# Use local cached debs from host (saves your bandwidth!)
# Change ip below to that of your apt-cacher-ng host
# Or comment this line out if you do not with to use caching
ADD 71-apt-cacher-ng /etc/apt/apt.conf.d/71-apt-cacher-ng

RUN apt-get -y update

#-------------Application Specific Stuff ----------------------------------------------------

ENV GS_VERSION 2.6.1
ENV GEOSERVER_DATA_DIR /opt/geoserver/data_dir

# Unset Java related ENVs since they may change with Oracle JDK
ENV JAVA_VERSION=
ENV JAVA_DEBIAN_VERSION=

# Set JAVA_HOME to /usr/lib/jvm/default-java and link it to OpenJDK installation
RUN ln -s /usr/lib/jvm/java-7-openjdk-amd64 /usr/lib/jvm/default-java
ENV JAVA_HOME /usr/lib/jvm/default-java

ADD resources /tmp/resources

# If a matching Oracle JDK tar.gz exists in /tmp/resources, move it to /var/cache/oracle-jdk7-installer
# where oracle-java7-installer will detect it
RUN if ls /tmp/resources/*jdk-*-linux-x64.tar.gz > /dev/null 2>&1; then \
      mkdir /var/cache/oracle-jdk7-installer && \
      mv /tmp/resources/*jdk-*-linux-x64.tar.gz /var/cache/oracle-jdk7-installer/; \
    fi;

# Install Oracle JDK (and uninstall OpenJDK JRE) if the build-arg ORACLE_JDK = true or an Oracle tar.gz
# was found in /tmp/resources
ARG ORACLE_JDK=false
RUN if ls /var/cache/oracle-jdk7-installer/*jdk-*-linux-x64.tar.gz > /dev/null 2>&1 || [ "$ORACLE_JDK" = true ]; then \
       apt-get autoremove --purge -y openjdk-7-jre-headless && \
       echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true \
         | debconf-set-selections && \
       echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu precise main" \
         > /etc/apt/sources.list.d/webupd8team-java.list && \
       apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EEA14886 && \
       apt-get update && \
       apt-get install -y oracle-java7-installer oracle-java7-set-default && \
       ln -s --force /usr/lib/jvm/java-7-oracle /usr/lib/jvm/default-java && \
       rm -rf /var/lib/apt/lists/* && \
       rm -rf /var/cache/oracle-jdk7-installer; \
       if [ -f /tmp/resources/jce_policy.zip ]; then \
         unzip -j /tmp/resources/jce_policy.zip -d /tmp/jce_policy && \
         mv /tmp/jce_policy/*.jar $JAVA_HOME/jre/lib/security/; \
       fi; \
    fi;

# A little logic that will fetch the geoserver war zip file if it
# is not available locally in the resources dir
RUN if [ ! -f /tmp/resources/geoserver.zip ]; then \
      wget -c http://downloads.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/geoserver-${GS_VERSION}-war.zip \
	-O /tmp/resources/geoserver.zip; \
    fi; \
    unzip /tmp/resources/geoserver.zip -d /tmp/geoserver \
    && mv /tmp/geoserver/geoserver.war /usr/local/tomcat/webapps/geoserver.war \
    && unzip /usr/local/tomcat/webapps/geoserver.war -d /usr/local/tomcat/webapps/geoserver \
    && rm -rf /tmp/geoserver

# Install any plugin zip files in resources/plugins
RUN if ls /tmp/resources/plugins/*.zip > /dev/null 2>&1; then \
      for p in /tmp/resources/plugins/*.zip; do \
        unzip $p -d /tmp/gs_plugin \
        && mv /tmp/gs_plugin/*.jar /usr/local/tomcat/webapps/geoserver/WEB-INF/lib/ \
        && rm -rf /tmp/gs_plugin; \
      done; \
    fi

# Overlay files and directories in resources/overlays if they exist
RUN rm /tmp/resources/overlays/README.txt && \
    if ls /tmp/resources/overlays/* > /dev/null 2>&1; then \
      cp -rf /tmp/resources/overlays/* /; \
    fi;

# Delete resources after installation
RUN rm -rf /tmp/resources
