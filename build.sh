#!/bin/sh
# Check the geoserver version specified in the Dockerfile and substitute the number in the globals starting with OLD.



# This represents the version we need GeoServer to move up to. ie the latest stable version
BUGFIX=0
MINOR=13
MAJOR=2

# Build Geoserver
echo "Building GeoServer using the specified version "
sed -i "s/${OLD_MAJOR}.${OLD_MINOR}.${OLD_BUGFIX}/${MAJOR}.${MINOR}.${BUGFIX}/g" Dockerfile
docker build --build-arg GS_VERSION=${MAJOR}.${MINOR}.${BUGFIX} -t kartoza/geoserver:${MAJOR}.${MINOR}.${BUGFIX} .

# Build Arguments - The change the defaults when building the image
#need to specify a different value.
```
--build-arg ORACLE_JDK=true
--build-arg COMMUNITY_MODULES=true
--build-arg TOMCAT_EXTRAS=false
```



