#!/bin/sh

MAJOR=2
MINOR=17
BUGFIX=2


# Build Geoserver
echo "Building GeoServer ${MAJOR}.${MINOR}.${BUGFIX} "

docker build --build-arg GS_VERSION=${MAJOR}.${MINOR}.${BUGFIX} -t kartoza/geoserver:${MAJOR}.${MINOR}.${BUGFIX} .

# Build Arguments - To change the defaults when building the image
#need to specify a different value.

#--build-arg WAR_URL=http://downloads.sourceforge.net/project/geoserver/GeoServer/<GS_VERSION>/geoserver-<GS_VERSION>-war.zip





