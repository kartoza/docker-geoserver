docker.io run --name="osm-africa-postgis" -t -d kartoza/postgis

docker.io run \
	--name=tilemill \
	--link osm-africa-postgis:osm-africa-postgis \
        -v /home/gisdata:/home/gisdata \
        -v /home/timlinux/Documents/MapBox:/Documents/MapBox \
	-p 20007:22 \
	-p 20008:20008 \
	-p 20009:20009 \
	-d \
	-t kartoza/tilemill
