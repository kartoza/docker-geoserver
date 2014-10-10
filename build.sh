#!/bin/sh

if [ ! -f resources/geoserver.zip ]
then
    wget -c http://downloads.sourceforge.net/project/geoserver/GeoServer/2.5.1/geoserver-2.5.1-bin.zip -O resources/geoserver.zip
fi
docker build -t kartoza/geoserver .
