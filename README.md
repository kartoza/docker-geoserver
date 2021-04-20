# docker-geoserver

A simple docker container that runs GeoServer influenced by this docker
recipe: https://github.com/eliotjordan/docker-geoserver/blob/master/Dockerfile

## Getting the image

There are various ways to get the image onto your system:

The preferred way (but using most bandwidth for the initial image) is to
get our docker trusted build like this:

```shell
VERSION=2.19.0
docker pull kartoza/geoserver:$VERSION
```
## Building the image


### To build yourself with a local checkout using the docker-compose.build.yaml:

Edit the `.env` to change the build arguments:

```
IMAGE_VERSION=tomcat image tag
JAVA_HOME= java home path corresponding to the tomcat version
WAR_URL= Default URL to fetch geoserver war or zip file
STABLE_PLUGIN_URL= URL to fetch geoserver plugins
ACTIVATE_ALL_STABLE_EXTENTIONS= Specifies whether to build all stable plugins or a single one
ACTIVATE_ALL_COMMUNITY_EXTENTIONS=Specifies whether to build all community plugins or a single one
GEOSERVER_UID=Specifies the uid to use for the user used to run GeoServer in the container
GEOSERVER_GID=Specifies the gid to use for the group used to run GeoServer in the container
```

```shell
git clone git://github.com/kartoza/docker-geoserver
cd docker-geoserver
docker-compose -f docker-compose-build.yml up -d --build
```

### Building with war file from a URL

If you need to build the image with a custom GeoServer war file that will be downloaded from a server, you
can pass the war file url as a build argument to docker, example:

```shell
docker build --build-arg WAR_URL=http://download2.nust.na/pub4/sourceforge/g/project/ge/geoserver/GeoServer/2.13.0/geoserver-2.13.0-war.zip --build-arg GS_VERSION=2.13.0
```

**Note: war file version should match the version number provided by `GS_VERSION` argument otherwise we will have a mismatch of plugins and GeoServer installed.**

### Building with a specific version of  Tomcat

To build using a specific tagged release for tomcat image set the
`IMAGE_VERSION` build-arg to `8-jre8`: See the [dockerhub tomcat](https://hub.docker.com/_/tomcat/)
to choose which tag you need to build against.

```
ie VERSION=2.17.0
docker build --build-arg IMAGE_VERSION=8-jre8 --build-arg GS_VERSION=2.17.0 -t kartoza/geoserver:${VERSION} .
```

For some recent builds it is necessary to set the JAVA_PATH as well (e.g. Apache Tomcat/9.0.36)
```
docker build --build-arg IMAGE_VERSION=9-jdk11-openjdk-slim --build-arg JAVA_HOME=/usr/local/openjdk-11/bin/java --build-arg GS_VERSION=2.17.0 -t kartoza/geoserver:2.17.0 .
```

### Building with file system overlays (advanced)

The contents of `resources/overlays` will be copied to the image file system
during the build. For example, to include a static Tomcat `setenv.sh`,
create the file at `resources/overlays/usr/local/tomcat/bin/setenv.sh`.

You can use this functionality to write a static GeoServer directory to
`/opt/geoserver/data_dir`, include additional jar files, and more.

Overlay files will overwrite existing destination files, so be careful!

#### Build with CORS Support

The image ships with CORS support. If you however need to modify the web.xml you
can mount `web.xml` to `/usr/local/tomcat/conf/web.xml`.

## Environment Variables
A full list of environment variables are specified in the .env file

### Default installed  plugins

The image is shipped with the following stable plugins:
* vectortiles-plugin
* wps-plugin
* printing-plugin
* libjpeg-turbo-plugin 
* control-flow-plugin 
* pyramid-plugin 
* gdal-plugin
* monitor-plugin
* inspire-plugin
* csw-plugin

**NB** Even though these plugins are part of the STABLE_PLUGINS the list above
is excluded from [Stable_plugins.txt](https://github.com/kartoza/docker-geoserver/blob/master/build_data/stable_plugins.txt)

The image provides the necessary plugin zip files which are used when activating 
the plugins. Not all the plugins will work out of the box because some plugins
needs extra dependencies which will need to be downloaded by the users. These 
dependencies are not bundled with the image because they have licences which are
not open for generic consumption by the public i.e [db2](https://docs.geoserver.org/stable/en/user/data/database/db2.html)

Other plugins also need extra environment variable ie community plugin `s3-geotiff-plugin`

####  Activate stable plugins during contain startup

The environment variable `STABLE_EXTENSIONS` can be used to activate plugins listed in
[Stable_plugins.txt](https://github.com/kartoza/docker-geoserver/blob/master/build_data/stable_plugins.txt)

Example

```
ie VERSION=2.16.2
docker run -d -p 8600:8080 --name geoserver -e STABLE_EXTENSIONS=charts-plugin,db2-plugin kartoza/geoserver:${VERSION} 

```
You can pass any comma separated plugins as defined in the text file `stable_plugins.txt`

**NB** Due to the nature of plugin ecosystem, there are new plugins that are always
being upgraded from community extensions to stable extensions. If the `stable_plugins.txt`
hasn't been updated with the latest changes you can still pass the enviroment variable with
the name of the plugin. The plugin will be downloaded and installed. 
This might slow down the process of starting GeoServer but will ensure all plugins are
activated

####  Activate community plugins during contain startup

The environment variable `COMMUNITY_EXTENSIONS` can be used to activate plugins listed in
[community_plugins.txt](https://github.com/kartoza/docker-geoserver/blob/master/build_data/community_plugins.txt)

Example 

``` 
ie VERSION=2.16.2
docker run -d -p 8600:8080 --name geoserver -e COMMUNITY_EXTENSIONS=gwc-sqlite-plugin,ogr-datastore-plugin kartoza/geoserver:${VERSION} 

```

**NB** Community plugins are always in an influx state and it is not guaranteed that plugins
will be accessible between each successive build.

### Using sample data

Geoserver ships with sample data which can be used by users to familiarize them with Geoserver.
This is not activated by default. You can activate it using the environment variable `SAMPLE_DATA=true` 

``` 
ie VERSION=2.16.2
docker run -d -p 8600:8080 --name geoserver -e SAMPLE_DATA=true kartoza/geoserver:${VERSION} 

```

### Enable disk quota storage in PostgreSQL backend

GeoServer defaults to using H2 datastore for configuring disk quota. You can alternatively
use the PostgreSQL backend as a disk quota store.

You will need to run a PostgreSQL DB and link it to a GeoServer instance.

``` 
docker run -d -p 5432:5432 --name db kartoza/postgis:13.0
docker run -d -p 8600:8080 --name geoserver --link db:db -e DB_BACKEND=POSTGRES -e HOST=db -e POSTGRES_PORT=5432 -e POSTGRES_DB=gis -e POSTGRES_USER=docker -e POSTGRES_PASS=docker kartoza/geoserver:2.18.0

```

### Running under SSL
You can use the environment variables to specify whether you want to run the GeoServer under SSL.
Credits to [letsencrpt](https://github.com/AtomGraph/letsencrypt-tomcat) for providing the solution to
run under SSL. 


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

You can also use a PFX file with this image.
Rename your PFX file as certificate.pfx and then mount the folder containing
your pfx file. This will be converted to perm files. 

**NB** When using PFX files make sure that the ALIAS_KEY you specify as
an environment variable matches the ALIAS_KEY that was used when generating
your PFX key.

A full list of SSL variables is provided here
* HTTP_PORT
* HTTP_PROXY_NAME
* HTTP_PROXY_PORT
* HTTP_REDIRECT_PORT
* HTTP_CONNECTION_TIMEOUT
* HTTP_COMPRESSION
* HTTP_MAX_HEADER_SIZE
* HTTPS_PORT
* HTTPS_MAX_THREADS
* HTTPS_CLIENT_AUTH
* HTTPS_PROXY_NAME
* HTTPS_PROXY_PORT
* HTTPS_COMPRESSION
* HTTPS_MAX_HEADER_SIZE
* JKS_FILE
* JKS_KEY_PASSWORD
* KEY_ALIAS
* JKS_STORE_PASSWORD
* P12_FILE


### Removing Tomcat extras 

To include Tomcat extras including docs, examples, and the manager webapp, set the
`TOMCAT_EXTRAS` environment variable to `true`:
**NB** You should configure the env variable `TOMCAT_PASSWORD` to use a 
strong password otherwise the default one is setup.

```
ie VERSION=2.16.2
docker run -it --name geoserver  -e TOMCAT_EXTRAS=true -p 8600:8080 kartoza/geoserver:${VERSION} 
```

**NB** GeoServer can run under tomcat or jetty. If the $WAR_URL you have
used is for jetty then you should not be using tomcat manager


### Upgrading image to use a specific version
During initialization the image will run a script that updates the passwords. This is
recommended to change passwords the first time that GeoServer runs but on subsequent 
upgrades a user should use the environment variable

`EXISTING_DATA_DIR=true`

This basically tells GeoServer that we are using a data directory that already exists
and no passwords should be changed.

### Installing extra fonts

If you have downloaded extra fonts you can mount the folder to the path
`/opt/fonts`. This will ensure that all the .ttf files are copied to the correct
path during initialisation.

```
ie VERSION=2.16.2
docker run -v fonts:/opt/fonts -p 8080:8080 -t kartoza/geoserver:${VERSION} .
```

### Other Environment variables supported
You can also use the following environment variables to pass arguments to GeoServer:

* `GEOSERVER_DATA_DIR=<PATH>`
* `ENABLE_JSONP=<true or false>`
* `MAX_FILTER_RULES=<Any integer>`
* `OPTIMIZE_LINE_WIDTH=<false or true>`
* `FOOTPRINTS_DATA_DIR=<PATH>`
* `GEOWEBCACHE_CACHE_DIR=<PATH>`
* `GEOSERVER_ADMIN_PASSWORD=<password>`
* `GEOSERVER_ADMIN_USER=<username>`
* `GEOSERVER_FILEBROWSER_HIDEFS=<false or true>`
* `XFRAME_OPTIONS="true"` - In order to prevent clickjacking attacks GeoServer defaults to 
setting the X-Frame-Options HTTP header to SAMEORIGIN. Controls whether the X-Frame-Options 
filter should be set at all. Default is true
* Tomcat properties:

  * You can change the variables based on [geoserver container considerations](http://docs.geoserver.org/stable/en/user/production/container.html). These arguments operate on the `-Xms` and `-Xmx` options of the Java Virtual Machine
  * `INITIAL_MEMORY=<size>` : Initial Memory that Java can allocate, default `2G`
  * `MAXIMUM_MEMORY=<size>` : Maximum Memory that Java can allocate, default `4G`

### Control flow properties

The control flow module is used to manage requests in GeoServer. Instructions on
what each parameter mean can be read from [documentation](http://docs.geoserver.org/latest/en/user/extensions/controlflow/index.html). 

* Control flow properties environment variables

    * `REQUEST_TIMEOUT=60`
    * `PARARELL_REQUEST=100`
    * `GETMAP=10`
    * `REQUEST_EXCEL=4`
    * `SINGLE_USER=6`
    * `GWC_REQUEST=16` 
    * `WPS_REQUEST=1000/d;30s`

**NB** You should customise these variables based on the resources available with your GeoServer

### Changing GeoServer password and username on runtime

The default GeoServer credentials are
Username = `admin` and the 
Password = `geoserver`

You can pass the environment variable `GEOSERVER_ADMIN_PASSWORD` and `GEOSERVER_ADMIN_USER` to
change it on runtime.

```
docker run --name "geoserver" -e GEOSERVER_ADMIN_USER=kartoza  -e GEOSERVER_ADMIN_PASSWORD=myawesomegeoserver -p 8080:8080 -d -t kartoza/geoserver
```

**NB** The docker-compose recipe uses the password `myawesomegeoserver`. It is highly
recommended not to run the container in production using these values.

#### Docker secrets

To avoid passing sensitive information in environment variables, `_FILE` can be appended to
some variables to read from files present in the container. This is particularly useful
in conjunction with Docker secrets, as passwords can be loaded from `/run/secrets/<secret_name>` e.g.:

* -e GEOSERVER_ADMIN_PASSWORD_FILE=/run/secrets/<geoserver_pass_secret>

For more information see [https://docs.docker.com/engine/swarm/secrets/](https://docs.docker.com/engine/swarm/secrets/).

Currently, `GEOSERVER_ADMIN_USER` and `GEOSERVER_ADMIN_PASSWORD` are supported.

## Clustering using JMS Plugin
GeoServer supports clustering using JMS cluster plugin or using the ActiveMQ-broker. 

You can read more about how to set-up clustering in [kartoza clustering](https://github.com/kartoza/docker-geoserver/blob/master/clustering/README.md)

## Mounting Configs

You can mount config file to the path `/settings`. These configs will
be used in favour of the defaults that are available from the [Build data](https://github.com/kartoza/docker-geoserver/tree/master/build_data)
directory

The configs that can be mounted are
* cluster.properties
* controlflow.properties
* embedded-broker.properties
* geowebcache-diskquota-jdbc.xml
* s3.properties
* tomcat-users.xml

Example
```
 docker run --name "geoserver" -e GEOSERVER_ADMIN_USER=kartoza  -v /data/controlflow.properties:/settings/controlflow.properties -p 8080:8080 -d -t kartoza/geoserver

```
## Running the Image 


### Run (automated using docker-compose)

**Note:** You probably want to use docker-compose for running as it will provide
a repeatable orchestrated deployment system.


We provide a sample ``docker-compose.yml`` file that illustrates
how you can establish a GeoServer + PostGIS.

If you are interested in the backups , add a section in the `docker-compose.yml`
following instructions from [docker-pg-backup](https://github.com/kartoza/docker-pg-backup/blob/master/docker-compose.yml#L23).

If you start the stack using the compose file make sure you login into GeoServer using 
username:`admin` and password:`myawesomegeoserver`.

**NB:** The username and password are specified in the `.env` file and it is recommended
to change them into something more secure.

Please read the ``docker-compose``
[documentation](https://docs.docker.com/compose/) for details on usage and syntax of ``docker-compose`` - it is not covered here.


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
 to delete the container data you need to run `docker-compose down -v`.


## Kubernetes (Helm Charts)

You can run the image in Kubernetes following the [recipe](https://github.com/kartoza/charts/tree/develop/charts/geoserver)

### Contributing to the image
We welcome users who want to contribute in enriching this service. We follow
the git principles and all pull requests should be against the develop branch so that
we can test them and when we are happy we push to the master branch.

### Support

If you require more substantial assistance from [kartoza](https://kartoza.com)  (because our work and interaction on docker-geoserver is pro bono),
please consider taking out a [Support Level Agreeement](https://kartoza.com/en/shop/product/support) 
## Credits

* Tim Sutton (tim@kartoza.com)
* Shane St Clair (shane@axiomdatascience.com)
* Alex Leith (alexgleith@gmail.com)
* Admire Nyakudya (admire@kartoza.com)
* Gavin Fleming (gavin@kartoza.com)
