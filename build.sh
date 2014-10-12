#!/bin/sh

if [ ! -f resources/geoserver.zip ]
then
    wget -c http://downloads.sourceforge.net/project/geoserver/GeoServer/2.5.2/geoserver-2.5.2-bin.zip -O resources/geoserver.zip
fi
docker build -t kartoza/geoserver .
