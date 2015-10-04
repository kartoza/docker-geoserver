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

RUN apt-get -y install unzip openjdk-7-jre-headless openjdk-7-jre

ADD resources /tmp/resources

# A little logic that will fetch the geoserver zip file if it
# is not available locally in the resources dir and
RUN if [ ! -f /tmp/resources/geoserver.zip ]; then \
    wget -c http://sourceforge.net/projects/geoserver/files/GeoServer/2.8.0/geoserver-2.8.0-bin.zip -O /tmp/resources/geoserver.zip; \
    fi; \
    unzip /tmp/resources/geoserver.zip -d /opt && mv -v /opt/geoserver* /opt/geoserver
ENV GEOSERVER_HOME /opt/geoserver
ENV JAVA_HOME /usr/

#ENTRYPOINT "/opt/geoserver/bin/startup.sh"
CMD "/opt/geoserver/bin/startup.sh"
EXPOSE 8080
