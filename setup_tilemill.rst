How I set up tile stream in docker:
===================================

Starting the committed instance::

    sudo docker run -d \
        -name="tilemill" \
        -p 2222:22 \
        -v /home/gisdata:/home/gisdata \
        -v /home/timlinux/Documents/MapBox:/Documents/MapBox \
        kartoza/tilemill \
        supervisord -n

Under this scenario, we share our gisdata directory from /home/gisdata to
a similarly named directory in the docker container. We also share our
MapBox directory to /Documents/MapBox which is where the docker installed
tilemill will look for and store its docs.

If you are using a linked container for postgis you might want to add the -link
option like this::

    sudo docker run -d \
        -name="tilemill" \
        -p 2222:22 \
        -link postgis:pg \
        -v /home/gisdata:/home/gisdata \
        -v /home/timlinux/Documents/MapBox:/Documents/MapBox \
        kartoza/tilemill \
        supervisord -n

With the ``-link`` option in place you can refer to the postgis database
host and port using these environment variables in your tilemill vm::



Connecting to the running instance with ssh port forwarding::

ssh localhost -p2222 -l root -L 20009:localhost:20009 -L 20008:localhost:20008


Now open your browser at: http://localhost:20009

Killing the running instance::

    sudo docker kill tilemill
    sudo docker rm tilemill

