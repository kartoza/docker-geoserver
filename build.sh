#!/bin/sh
# Check the geoserver version specified in the Dockerfile and substitute the number in the globals starting with OLD.

## GLOBALS
# This specifies the current version that is specified in the Dockerfile and download script (the previous stable version if a new stable version is available).
OLD_BUGFIX=1
OLD_MINOR=12
OLD_MAJOR=2

# This represents the version we need geoserver to move up to. ie the lattest stable version
BUGFIX=2
MINOR=12
MAJOR=2

## Prepare to bump geoserver to a specific version

if grep -rl -q "${OLD_MAJOR}.${OLD_MINOR}.${OLD_BUGFIX}" Dockerfile

then
    echo "We are going to upgrade the geoserver version"
    sed -i "s/${OLD_MAJOR}.${OLD_MINOR}.${OLD_BUGFIX}/${MAJOR}.${MINOR}.${BUGFIX}/g" Dockerfile
	sed -i "s/${OLD_MAJOR}.${OLD_MINOR}.${OLD_BUGFIX}/${MAJOR}.${MINOR}.${BUGFIX}/g" download.sh
	./download.sh
	docker build -t kartoza/geoserver:${MAJOR}.${MINOR}.${BUGFIX} .
else
    echo "It seems the geoserver has not been upgraded. We will download the extensions and build geoserver."
	./download.sh
	docker build -t kartoza/geoserver:${OLD_MAJOR}.${OLD_MINOR}.${OLD_BUGFIX} .
fi

