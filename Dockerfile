#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
FROM ubuntu:trusty
MAINTAINER Tim Sutton<tim@linfiniti.com>

RUN  export DEBIAN_FRONTEND=noninteractive
ENV  DEBIAN_FRONTEND noninteractive
RUN  dpkg-divert --local --rename --add /sbin/initctl
#RUN  ln -s /bin/true /sbin/initctl

# Use local cached debs from host (saves your bandwidth!)
# Change ip below to that of your apt-cacher-ng host
# Or comment this line out if you do not with to use caching
ADD 71-apt-cacher-ng /etc/apt/apt.conf.d/71-apt-cacher-ng

RUN echo "deb http://archive.ubuntu.com/ubuntu trusty main universe" > /etc/apt/sources.list
#RUN apt-get -y update

#-------------Application Specific Stuff ----------------------------------------------------

RUN apt-get -y install unzip openjdk-7-jre-headless openjdk-7-jre
ADD geoserver.zip /tmp/geoserver.zip
# Next three lines pilfered from 
# https://ge.dec.wa.gov.au/_/dockers/dpaw_docker/geoserver/Dockerfile
#RUN wget http://downloads.sourceforge.net/project/geoserver/GeoServer/2.4.1/geoserver-2.4.1-bin.zip -O /tmp/geoserver.zip
RUN unzip /tmp/geoserver.zip -d /opt && mv -v /opt/geoserver* /opt/geoserver
ENV GEOSERVER_HOME /opt/geoserver

ENTRYPOINT "/opt/geoserver/bin/startup.sh"
EXPOSE 8080
