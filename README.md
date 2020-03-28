# docker-geoserver

A simple docker container that runs GeoServer influenced by this docker
recipe: https://github.com/eliotjordan/docker-geoserver/blob/master/Dockerfile

## Getting the image

There are various ways to get the image onto your system:

The preferred way (but using most bandwidth for the initial image) is to
get our docker trusted build like this:

```shell
docker pull kartoza/geoserver
```

### To build yourself with a local checkout using the build script:

Edit the build script to change the following variables:

- The variables below represent the latest stable release you need to build. i.e 2.15.2

   ```text
   BUGFIX=2
   MINOR=16
   MAJOR=2
   ```

```shell
git clone git://github.com/kartoza/docker-geoserver
cd docker-geoserver
./build.sh
```

Ensure that you look at the build script to see what other build arguments you can include whilst building your image.

If you do not intend to jump between versions you need to specify that in the build script.

### Building with war file from a URL

If you need to build the image with a custom GeoServer war file that will be downloaded from a server, you
can pass the war file url as a build argument to docker, example:

```shell
docker build --build-arg WAR_URL=http://download2.nust.na/pub4/sourceforge/g/project/ge/geoserver/GeoServer/2.13.0/geoserver-2.13.0-war.zip --build-arg GS_VERSION=2.13.0
```

**Note: war file version should match the version number provided by `GS_VERSION` argument otherwise we will have a mismatch of plugins and GeoServer installed.**


### Activate plugins on runtime

The image is shipped with the following stable plugins:
* vectortiles-plugin
* wps-plugin
* printing-plugin
* libjpeg-turbo-plugin 
* control-flow-plugin 
* pyramid-plugin 
* gdal-plugin

If you need to use other plugin you just pass an environment variable on startup which will
activate the plugin ie
```
ie VERSION=2.16.2
docker run -d -p 8600:8080 --name geoserver -e STABLE_EXTENSIONS=charts-plugin,db2-plugin kartoza/geoserver:${VERSION} 

```
You can pass as many comma separated plugins as defined in the text file `stable_plugins.txt`

You can also activate the community plugins as defined in `community_plugins.txt`
``` 
ie VERSION=2.16.2
docker run -d -p 8600:8080 --name geoserver -e COMMUNITY_EXTENSIONS=gwc-sqlite-plugin,ogr-datastore-plugin kartoza/geoserver:${VERSION} 

```
### Using sample data

If you need to play around with the default data directory you can activate it using the environment
variable `SAMPLE_DATA=true` 

``` 
ie VERSION=2.16.2
docker run -d -p 8600:8080 --name geoserver -e SAMPLE_DATA=true kartoza/geoserver:${VERSION} 

```

### Running under SSL
You can use the environment variables to specify whether you want to run the GeoServer under SSL.
Credits to [letsencrpt](https://github.com/AtomGraph/letsencrypt-tomcat) for providing the solution to
run under SSL. Currently the container does not use PFX files , it ony uses pkcs12

If you set the environment variable `SSL=true` but do not provide the pem files (fullchain.pem and privkey.pem)
the container will generate a self signed SSL certificates.

```
ie VERSION=2.16.2
docker run -it --name geoserver  -e PKCS12_PASSWORD=geoserver -e JKS_KEY_PASSWORD=geoserver -e JKS_STORE_PASSWORD=geoserver -e SSL=true -p 8443:8443 -p 8600:8080 kartoza/geoserver:${VERSION} 
```

 If you already have your own perm files (fullchain.pem and privkey.pem) you can mount the directory containing your keys as:

``` 
ie VERSION=2.16.2
docker run -it --name geo -v /etc/letsencrpt:/etc/letsencrypt  -e PKCS12_PASSWORD=geoserver -e JKS_KEY_PASSWORD=geoserver -e JKS_STORE_PASSWORD=geoserver -e SSL=true -p 8443:8443 -p 8600:8080 kartoza/geoserver:${VERSION}  

```
A full list of SSL variables is provided here
* HTTP_PORT
* HTTP_PROXY_NAME
* HTTP_PROXY_PORT
* HTTP_REDIRECT_PORT
* HTTP_CONNECTION_TIMEOUT
* HTTP_COMPRESSION
* HTTPS_PORT
* HTTPS_MAX_THREADS
* HTTPS_CLIENT_AUTH
* HTTPS_PROXY_NAME
* HTTPS_PROXY_PORT
* HTTPS_COMPRESSION
* JKS_FILE
* JKS_KEY_PASSWORD
* KEY_ALIAS
* JKS_STORE_PASSWORD
* P12_FILE


### Removing Tomcat extras during build

To remove Tomcat extras including docs, examples, and the manager webapp, set the
`TOMCAT_EXTRAS` build-arg to `false`:

```
ie VERSION=2.16.2
docker build --build-arg TOMCAT_EXTRAS=false --build-arg GS_VERSION=2.13.0 -t kartoza/geoserver:${VERSION} .
```

### Building with specific version of  Tomcat

To build using a specific tagged release for tomcat image set the
`IMAGE_VERSION` build-arg to `8-jre8`: See the [dockerhub tomcat](https://hub.docker.com/_/tomcat/)
to choose which tag you need to build against.

```
ie VERSION=2.16.2
docker build --build-arg IMAGE_VERSION=8-jre8 --build-arg GS_VERSION=2.13.0 -t kartoza/geoserver:${VERSION} .
```

### Building with file system overlays (advanced)

The contents of `resources/overlays` will be copied to the image file system
during the build. For example, to include a static Tomcat `setenv.sh`,
create the file at `resources/overlays/usr/local/tomcat/bin/setenv.sh`.

You can use this functionality to write a static GeoServer directory to
`/opt/geoserver/data_dir`, include additional jar files, and more.

If you have an already existing `data_dir` with a security setup from another Geoserver: set `EXISTING_DATA_DIR=true`.
This will keep the passwords from getting changed by docker. 

Overlay files will overwrite existing destination files, so be careful!

### Upgrading image to use a specific version
During initialization the image will run a script that updates the passwords. This is
recommended to change passwords the first time that GeoServer runs but on subsequent 
upgrades a use should use the environment variable

`EXISTING_DATA_DIR=true`

This basically tells GeoServer that we are using a data directory that already exists
and no passwords should be changed.

#### Build with CORS Support

The contents of `resources/overlays` will be copied to the image file system
during the build. For example, to include a static web xml with CORS support `web.xml`,
create the file at `resources/overlays/usr/local/tomcat/conf/web.xml`.

## Run (manual docker commands)

**Note:** You probably want to use docker-compose for running as it will provide
a repeatable orchestrated deployment system.

You probably want to also have PostGIS running too. To create a running
container do:

```
ie VERSION=2.16.2
docker run --name "postgis" -d -t kartoza/postgis:12.0
docker run --name "geoserver"  --link postgis:postgis -p 8080:8080 -d -t kartoza/geoserver:${VERSION}
```

You can also use the following environment variables to pass a
user name and password to PostGIS:

* `-e USERNAME=<PGUSER>`
* `-e PASS=<PGPASSWORD>`

You can also use the following environment variables to pass arguments to GeoServer:

* `GEOSERVER_DATA_DIR=<PATH>`
* `ENABLE_JSONP=<true or false>`
* `MAX_FILTER_RULES=<Any integer>`
* `OPTIMIZE_LINE_WIDTH=<false or true>`
* `FOOTPRINTS_DATA_DIR=<PATH>`
* `GEOWEBCACHE_CACHE_DIR=<PATH>`
* `GEOSERVER_ADMIN_PASSWORD=<password>`

In order to prevent clickjacking attacks GeoServer defaults to 
setting the X-Frame-Options HTTP header to SAMEORIGIN. Controls whether the X-Frame-Options 
filter should be set at all. Default is true
* `XFRAME_OPTIONS="true"`
* Tomcat properties:

  * You can change the variables based on [geoserver container considerations](http://docs.geoserver.org/stable/en/user/production/container.html). These arguments operate on the `-Xms` and `-Xmx` options of the Java Virtual Machine
  * `INITIAL_MEMORY=<size>` : Initial Memory that Java can allocate, default `2G`
  * `MAXIMUM_MEMORY=<size>` : Maximum Memory that Java can allocate, default `4G`

### Control flow properties

The control flow module is installed by default and it is used to manage request in geoserver. In order
to customise it based on your resources and use case read the instructions from
[documentation](http://docs.geoserver.org/latest/en/user/extensions/controlflow/index.html). 
These options can be controlled by environment variables

* Control flow properties environment variables

    if a request waits in queue for more than 60 seconds it's not worth executing,
    the client will  likely have given up by then
    * REQUEST_TIMEOUT=60 
    don't allow the execution of more than 100 requests total in parallel
    * PARARELL_REQUEST=100 
    don't allow more than 10 GetMap in parallel
    * GETMAP=10 
    don't allow more than 4 outputs with Excel output as it's memory bound
    * REQUEST_EXCEL=4 
    don't allow a single user to perform more than 6 requests in parallel
    (6 being the Firefox default concurrency level at the time of writing)
    * SINGLE_USER=6 
    don't allow the execution of more than 16 tile requests in parallel
    (assuming a server with 4 cores, GWC empirical tests show that throughput
    peaks up at 4 x number of cores. Adjust as appropriate to your system)
    * GWC_REQUEST=16 
    * WPS_REQUEST=1000/d;30s


**Note:**

### Changing GeoServer password on runtime

The default GeoServer user is 'admin' and the password is 'geoserver'. You can pass the environment variable
GEOSERVER_ADMIN_PASSWORD to  change it on runtime.

```
docker run --name "geoserver"  -e GEOSERVER_ADMIN_PASSWORD=myawesomegeoserver -p 8080:8080 -d -t kartoza/geoserver
```

## Run (automated using docker-compose)

We provide a sample ``docker-compose.yml`` file that illustrates
how you can establish a GeoServer + PostGIS + GeoGig orchestrated environment
with nightly backups that are synchronised to your backup server via btsync.

If you are **not** interested in the backups, GeoGig and btsync options, comment
out those services in the ``docker-compose.yml`` file.

If you start the stack using the compose file make sure you login into GeoServer using username:`admin`
and password:`myawesomegeoserver` as specified by the env file `geoserver.env`

Please read the ``docker-compose``
[documentation](https://docs.docker.com/compose/) for details
on usage and syntax of ``docker-compose`` - it is not covered here.

If you **are** interested in btsync backups, install [Resilio sync]
on your desktop NAS or other backup  destination and create two
folders:

* one for database backup dumps
* one for geoserver data dir

Then make a copy of each of the provided EXAMPLE environment files e.g.:

```shell
cp docker-env/btsync-db.env.EXAMPLE docker-env/btsync-db.env
cp docker-env/btsync-media.env.EXAMPLE docker-env/btsync-media.env
```

Then edit the two env files, placing your Read/Write Resilio keys
in the place provided.

To run the example do:

```shell
docker-compose up
```

Which will run everything in the foreground giving you the opportunity
to peruse logs and see that everything spins up nicely.

Once all services are started, test by visiting the GeoServer landing
page in your browser: [http://localhost:8600/geoserver](http://localhost:8600/geoserver).

To run in the background rather, press ``ctrl-c`` to stop the
containers and run again in the background:

```shell
docker-compose up -d
```

**Note:** The ``docker-compose.yml`` **uses host based volumes** so
when you remove the containers, **all data will be kept**. Using host based volumes
 ensures that your data persists between invocations of the compose file. If you need
 to delete the container data you need to run `docker volume prune`. Pruning the volumes will
 remove all the storage volumes that are not in use so users need to be careful of such a move.
 Either set up btsync (and test to verify that your backups are working, we take
**no responsibility** if the examples provided here do not produce
a reliable backup system).

## Run (automated using rancher)

An even nicer way to run the examples provided is to use our Rancher
Catalogue Stack for GeoServer. See [http://rancher.com](http://rancher.com)
for more details on how to set up and configure your Rancher
environment. Once Rancher is set up, use the Admin -> Settings menu to
add our Rancher catalogue using this URL:

https://github.com/kartoza/kartoza-rancher-catalogue

Once your settings are saved open a Rancher environment and set up a
stack from the catalogue's 'Kartoza' section - you will see
GeoServer listed there.

If you want to synchronise your GeoServer settings and database backups
(created by the nightly backup tool in the stack), use [Resilio
sync](https://www.Resilio.com/) to create two Read/Write keys:

* one for database backups
* one for GeoServer media backups

**Note:** Resilio sync is not Free Software. It is free to use for
individuals. Business users need to pay - see their web site for details.

You can try a similar approach with Syncthing or Seafile (for free options)
or Dropbox or Google Drive if you want to use another commercial product. These
products all have one limitation though: they require interaction
to register applications or keys. With Resilio Sync you can completely
automate the process without user intervention.

## Storing data on the host rather than the container.

Docker volumes can be used to persist your data.

If you need to use geoserver data directory that contains sample examples and configurations download
it from [geonode](http://build.geonode.org/geoserver/latest/) site as indicated below:

```shell

# Example - ${GS_VERSION} is the geoserver version i.e 2.13.0
wget http://build.geonode.org/geoserver/latest/data-2.13.x.zip
unzip data-2.13.x.zip -d ~/geoserver_data
cp scripts/controlflow.properties ~/geoserver_data
chmod -R a+rwx ~/geoserver_data
docker run -d -p 8580:8080 --name "geoserver" -v $HOME/geoserver_data:/opt/geoserver/data_dir kartoza/geoserver:${GS_VERSION}
```

Create an empty data directory to use to persist your data.

```shell
mkdir -p ~/geoserver_data && chmod -R a+rwx ~/geoserver_data
docker run -d -v $HOME/geoserver_data:/opt/geoserver/data_dir kartoza/geoserver
```


## Credits

* Tim Sutton (tim@kartoza.com)
* Shane St Clair (shane@axiomdatascience.com)
* Alex Leith (alexgleith@gmail.com)
* Admire Nyakudya (admire@kartoza.com)
* Gavin Fleming (gavin@kartoza.com)
