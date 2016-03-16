To include files in the container file system at arbitrary locations, build
a directory structure from / here and include the files at the desired location.

For example, to include a static Tomcat setenv.sh in the build, place it at:

resources/overlays/usr/local/tomcat/bin/setenv.sh

Other overlay examples include static GeoServer data directories, the Marlin renderer, etc.

Note that overlay files will overwrite existing destination files, and that
files in the overlay root will be copied to the container root
(e.g. resources/overlay/somefile.txt will be copied to /somefile.txt).

Be careful!
