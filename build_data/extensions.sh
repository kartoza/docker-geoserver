#!/bin/sh
set -eux

cd  /work/
python3 stable_plugins.py 2.25.1 https://sourceforge.net/projects/geoserver/files/GeoServer

python3 community_plugins.py  2.25.x



