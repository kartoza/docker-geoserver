#!/bin/sh
# Check the GeoServer version specified in the Dockerfile and substitute the number in the globals starting with OLD.

# This represents the version we need GeoServer to move up to. ie the latest stable version.
# Change this to reflect changes
BUGFIX=0
MINOR=14
MAJOR=2

#Represents the current version defined in the Dockerfile and used in the setup script
OLD_MAJOR=2
OLD_MINOR=13
OLD_BUGFIX=0

# Build Geoserver
echo "Building GeoServer using the specified version "
sed -i "s/${OLD_MAJOR}.${OLD_MINOR}.${OLD_BUGFIX}/${MAJOR}.${MINOR}.${BUGFIX}/g" Dockerfile
docker build --build-arg GS_VERSION=${MAJOR}.${MINOR}.${BUGFIX} -t kartoza/geoserver:${MAJOR}.${MINOR}.${BUGFIX} .

# Build Arguments - To change the defaults when building the image
#need to specify a different value.
```
--build-arg ORACLE_JDK=true
--build-arg COMMUNITY_MODULES=true
--build-arg TOMCAT_EXTRAS=false
--build-arg WAR_URL=http://downloads.sourceforge.net/project/geoserver/GeoServer/<GS_VERSION>/geoserver-<GS_VERSION>-war.zip
--build-arg INITIAL_MEMORY=2G
--build-arg MAXIMUM_MEMORY=4G
```



