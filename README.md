# Table of Contents
* [Kartoza docker-geoserver](#kartoza-docker-geoserver)
   * [Getting the image](#getting-the-image)
       * [Pulling from Dockerhub](#pulling-from-dockerhub)
       * [Building the image](#building-the-image)
       * [Local build using repository checkout](#local-build-using-repository-checkout)
       * [Building with a specific version of  Tomcat](#building-with-a-specific-version-of--tomcat)
       * [Building on Windows](#building-on-windows)
   * [Environment Variables](#environment-variables)
       * [Default installed  plugins](#default-installed--plugins)
           * [Activate stable plugins during contain startup](#activate-stable-plugins-during-contain-startup)
           * [Activate community plugins during contain startup](#activate-community-plugins-during-contain-startup)
       * [Using sample data](#using-sample-data)
       * [Enable disk quota storage in PostgreSQL backend](#enable-disk-quota-storage-in-postgresql-backend)
           * [Using SSL and Default PostgreSQL ssl certificates](#using-ssl-and-default-postgresql-ssl-certificates)
           * [Using SSL certificates signed by a certificate authority](#using-ssl-certificates-signed-by-a-certificate-authority)
       * [Activating JNDI PostgreSQL connector](#activating-jndi-postgresql-connector)
       * [Running under SSL](#running-under-ssl)
       * [Proxy Base URL](#proxy-base-url)
       * [Removing Tomcat extras](#removing-tomcat-extras)
       * [Upgrading image to use a specific version](#upgrading-image-to-use-a-specific-version)
       * [Installing extra fonts](#installing-extra-fonts)
       * [Other Environment variables supported](#other-environment-variables-supported)
       * [Control flow properties](#control-flow-properties)
       * [Changing GeoServer password and username](#changing-geoserver-password-and-username)
           * [Docker secrets](#docker-secrets)
   * [Mounting Configs](#mounting-configs)
       * [CORS Support](#cors-support)
   * [Clustering using JMS Plugin](#clustering-using-jms-plugin)
   * [Running the Image](#running-the-image)
       * [Run (automated using docker-compose)](#run-automated-using-docker-compose)
       * [Reverse Proxy using NGINX](#reverse-proxy-using-nginx)
       * [Additional Notes for MacOS M1 Chip](#additional-notes-for-macos-m1-chip)
       * [Reverse Proxy using NGINX](#reverse-proxy-using-nginx-1)
   * [Kubernetes (Helm Charts)](#kubernetes-helm-charts)
   * [Contributing to the image](#contributing-to-the-image)
       * [Upgrading GeoServer Versions](#upgrading-geoserver-versions)
   * [Support](#support)
   * [Credits](#credits)


# Kartoza docker-geoserver

A simple docker container that runs GeoServer influenced by this [docker recipe](https://github.com/eliotjordan/docker-geoserver/blob/master/Dockerfile)

## Getting the image

There are various ways to get the image onto your system:

   * Pulling from Dockerhub
   * Local build using docker-compose

### Pulling from Dockerhub

The preferred way (but using most bandwidth for the initial image) is to
get our docker trusted build like this:

```shell
VERSION=2.21.2
docker pull kartoza/geoserver:$VERSION
```
### Building the image


### Local build using repository checkout

To build yourself with a local checkout using the docker-compose.build.yaml:

1. Clone the GitHub repository:

   ```shell
   git clone https://github.com/kartoza/docker-geoserver
   ```
2. Edit the [.env](https://github.com/kartoza/docker-geoserver/blob/master/.env) to change the build arguments:

   ```
   IMAGE_VERSION=[dockerhub tomcat](https://hub.docker.com/_/tomcat/)
   JAVA_HOME= java home path corresponding to the tomcat version
   WAR_URL= Default URL to fetch GeoServer war or zip file
   STABLE_PLUGIN_URL= URL to fetch GeoServer plugins
   DOWNLOAD_ALL_STABLE_EXTENSIONS= Specifies whether to download all stable plugins or a single one
   DOWNLOAD_ALL_COMMUNITY_EXTENSIONS=Specifies whether to download all community plugins or a single one
   GEOSERVER_UID=Specifies the uid to use for the user used to run GeoServer in the container
   GEOSERVER_GID=Specifies the gid to use for the group used to run GeoServer in the container
   ```

3. Build the container and spin up the services
   ```shell
   cd docker-geoserver
   docker-compose -f docker-compose-build.yml up -d --build
   ```


### Building with a specific version of  Tomcat

To build using a specific tagged release for tomcat image set the
`IMAGE_VERSION` build-arg to `8-jre8`: See the [dockerhub tomcat](https://hub.docker.com/_/tomcat/)
to choose which tag you need to build against.

```
ie VERSION=2.21.2
docker build --build-arg IMAGE_VERSION=8-jre8 --build-arg GS_VERSION=2.21.2 -t kartoza/geoserver:${VERSION} .
```

For some recent builds it is necessary to set the JAVA_PATH as well (e.g. Apache Tomcat/9.0.36)
```
docker build --build-arg IMAGE_VERSION=9-jdk11-openjdk-slim --build-arg JAVA_HOME=/usr/local/openjdk-11/bin/java --build-arg GS_VERSION=2.21.2 -t kartoza/geoserver:2.21.2 .
```

**Note:** Please check the [GeoServer documentation](https://docs.geoserver.org/stable/en/user/production/index.html) to see which tomcat versions
are supported.

### Building on Windows

These instructions detail the recommended process for reliably building this on Windows.

Prerequisites - You will need to have this software preinstalled on the system being used to build the Geoserver image:

   * Docker Desktop with WSL2
   * [Java JDK](https://jdk.java.net/)
   * [Conda](https://conda.io/)
   * GDAL (Install with Conda)

Add the conda-forge channel to your conda installation:

```pwsh
conda config --add channels conda-forge
```

Now create a new conda environment with GDAL, installed from conda. Ensure that this environment is active when running the docker build, e.g.

```pwsh
conda create -n geoserver-build -c conda-forge python gdal
conda activate geoserver-build
```

Modify the `.env` with the appropriate environment variables. It is recommended that shortpaths (without whitespace) are used with forward slashes to prevent errors. You can get the current java command short path with powershell:

```pwsh
(New-Object -ComObject Scripting.FileSystemObject).GetFile((get-command java).Source).ShortPath
```

Running the above command should yield a path similar to `C:/PROGRA~1/Java/JDK-15~1.2/bin/java.exe`, which can be assigned to `JAVA_HOME` in the environment confoguration file.

Then run the docker build commands. If you encounter issues, you may want to ensure that you try to build the image without the cache and then run docker up separately:

```pwsh
docker-compose -f docker-compose-build.yml build --force-rm --no-cache
docker-compose -f docker-compose-build.yml up -d
```

## Environment Variables
A full list of environment variables are specified in the [.env](https://github.com/kartoza/docker-geoserver/blob/master/.env) file

### Default installed  plugins

The image ships with the following stable plugins:
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

**Note:** The plugins listed above are omitted from [Stable_plugins.txt](https://github.com/kartoza/docker-geoserver/blob/master/build_data/stable_plugins.txt)
even though they are considered [stable plugins](https://sourceforge.net/projects/geoserver/files/GeoServer/2.21.2/extensions/)
The image activates them on startup.

The image provides the necessary plugin zip files which are used when activating the
plugins. Not all the plugins will work out of the box because some plugins have
extra dependencies which need to be downloaded and installed by users because of
their licence terms i.e. [db2](https://docs.geoserver.org/stable/en/user/data/database/db2.html)

Some  plugins also need extra configuration parameters i.e. community plugin `s3-geotiff-plugin`

####  Activate stable plugins during contain startup

The environment variable `STABLE_EXTENSIONS` can be used to activate plugins listed in
[Stable_plugins.txt](https://github.com/kartoza/docker-geoserver/blob/master/build_data/stable_plugins.txt)

Example

```
ie VERSION=2.21.2
docker run -d -p 8600:8080 --name geoserver -e STABLE_EXTENSIONS=charts-plugin,db2-plugin kartoza/geoserver:${VERSION}

```
You can pass any comma-separated plugins as defined in the text file `stable_plugins.txt`

**Note** Due to the nature of the plugin ecosystem, there are new plugins that are always
being upgraded from community extensions to stable extensions. If the `stable_plugins.txt`
hasn't been updated with the latest changes you can still pass the environment variable with
the name of the plugin. The plugin will be downloaded and installed.
This might slow down the process of starting GeoServer but will ensure all plugins get
activated

####  Activate community plugins during contain startup

The environment variable `COMMUNITY_EXTENSIONS` can be used to activate plugins listed in
[community_plugins.txt](https://github.com/kartoza/docker-geoserver/blob/master/build_data/community_plugins.txt)

Example

```
ie VERSION=2.21.2
docker run -d -p 8600:8080 --name geoserver -e COMMUNITY_EXTENSIONS=gwc-sqlite-plugin,ogr-datastore-plugin kartoza/geoserver:${VERSION}

```

You can also pass the environment variable `FORCE_DOWNLOAD_COMMUNITY_EXTENSIONS=true` to download
the latest community plugins during initialisation of the container.

**Note:** Community plugins are always in flux state. There is no guarantee that
plugins will be accessible between each successive build. You can build the extensions
following the guidelines from [GeoServer develop guidelines](https://docs.geoserver.org/latest/en/developer/maven-guide/index.html#building-extensions)

### Using sample data

Geoserver ships with sample data which can be used by users to familiarize them with software.
This is not activated by default. You can activate it using the environment variable `SAMPLE_DATA=true`

```
ie VERSION=2.21.2
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

Some additional environment variables to use when activating the disk quota are:

* DISK_QUOTA_SIZE - Specifies the size of the disk quota you need to use. Defaults to 20Gb

If you are using the `kartoza/docker-postgis` image as a database backend you can additionally
configure communication between the containers to use [SSL](https://github.com/kartoza/docker-postgis#postgres-ssl-setup)

#### Using SSL and Default PostgreSQL ssl certificates

When the environment variable `FORCE_SSL=TRUE` is set for the database container you
will need to set `SSL_MODE=allow` in the GeoServer container.

#### Using SSL certificates signed by a certificate authority

When the environment variable `FORCE_SSL=TRUE` is set for the database container you
will need to set `SSL_MODE` to either `verify-full` or `verify-ca`
for the GeoServer container. You will also need to mount the ssl certificates
you have done in the DB.

In the GeoServer container, the certificates need to be mounted to the folder
specified by the certificate directory ${CERT_DIR}

```
SSL_CERT_FILE=/etc/certs/fullchain.pem
SSL_KEY_FILE=/etc/certs/privkey.pem
SSL_CA_FILE=/etc/certs/root.crt
```

### Activating JNDI PostgreSQL connector
When defining vector stores you can use the JNDI pooling. To set this up you will need to activate the following environment variable `POSTGRES_JNDI=TRUE`. By default, the environment
the variable is set to `FALSE`
Additionally, you will need to define parameters to connect to an existing PostgreSQL database

```
POSTGRES_JNDI=TRUE
HOST=${POSTGRES_HOSTNAME}
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASS=${POSTGRES_PASS}
```
If you are using the [kartoza/postgis image](https://github.com/kartoza/docker-postgis)
with the env variable `FORCE_SSL=TRUE` you will also need to set the environment
variable `SSL_MODE` to correspond to value mentioned in [kartoza/postgis ssl](https://github.com/kartoza/docker-postgis#postgres-ssl-setup)

When defining the parameters for the store in GeoServer you will need to set
`jndiReferenceName=java:comp/env/jdbc/postgres`

### Running under SSL
You can use the environment variables to specify whether you want to run the GeoServer under SSL.
Credits to [letsencrpt](https://github.com/AtomGraph/letsencrypt-tomcat) for providing the solution to
run under SSL.


If you set the environment variable `SSL=true` but do not provide the pem files (fullchain.pem and privkey.pem)
the container will generate a self-signed SSL certificates.

```
ie VERSION=2.21.2
docker run -it --name geoserver  -e PKCS12_PASSWORD=geoserver -e JKS_KEY_PASSWORD=geoserver -e JKS_STORE_PASSWORD=geoserver -e SSL=true -p 8443:8443 -p 8600:8080 kartoza/geoserver:${VERSION}
```

If you already have your perm files (fullchain.pem and privkey.pem) you can mount the directory containing your keys as:

```
ie VERSION=2.21.2
docker run -it --name geo -v /etc/certs:/etc/certs  -e PKCS12_PASSWORD=geoserver -e JKS_KEY_PASSWORD=geoserver -e JKS_STORE_PASSWORD=geoserver -e SSL=true -p 8443:8443 -p 8600:8080 kartoza/geoserver:${VERSION}

```

You can also use a PFX file with this image.
Rename your PFX file as certificate.pfx and then mount the folder containing
your pfx file. This will be converted to perm files.

**Note** When using PFX files make sure that the ALIAS_KEY you specify as
an environment variable matches the ALIAS_KEY that was used when generating
your PFX key.

A full list of SSL variables is provided here
* HTTP_PORT
* HTTP_PROXY_NAME
* HTTP_PROXY_PORT
* HTTP_REDIRECT_PORT
* HTTP_CONNECTION_TIMEOUT
* HTTP_COMPRESSION
* HTTP_SCHEME
* HTTP_MAX_HEADER_SIZE
* HTTPS_SCHEME
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

### Proxy Base URL

For the server to report a full proxy base url, you need to pass
the following env variable i.e.

```
HTTP_PROXY_NAME
HTTP_PROXY_PORT
```

If you are running GeoServer under SSL with reverse proxy i.e nginx you will need
to set the following env variables

Example below:

```bash
HTTP_PROXY_NAME=foo.org
HTTP_SCHEME=https
```

This will prevent the login form from sending insecure http post request as experienced
in [login issue](https://github.com/kartoza/docker-geoserver/issues/293)

For SSL based connections the env variables are:

```
HTTPS_PROXY_NAME
HTTPS_PROXY_PORT
HTTPS_SCHEME
```

### Removing Tomcat extras

To include Tomcat extras including docs, examples, and the manager webapp, set the
`TOMCAT_EXTRAS` environment variable to `true`:

**Note:** If `TOMCAT_EXTRAS` is set to true then you should configure  `TOMCAT_PASSWORD`
to use a strong password otherwise the default one is set up.

```
ie VERSION=2.21.2
docker run -it --name geoserver  -e TOMCAT_EXTRAS=true -p 8600:8080 kartoza/geoserver:${VERSION}
```

**Note:** If `TOMCAT_EXTRAS` is set to false, requests to the root webapp ("/") will return HTTP status code 404. To issue a redirect to the GeoServer webapp ("/geoserver/web") set `ROOT_WEBAPP_REDIRECT=true`

### Upgrading image to use a specific version
During initialization, the image will run a script that updates the passwords. This
is recommended to change passwords the first time that GeoServer runs. If you are migrating
your GeoServer instance, from one a lower version to a higher one you will need to set the
environment variable `EXISTING_DATA_DIR`; unset it to run the initialization script.

The environment variable will ensure that the password initialization is skipped
during the startup procedure.

### Installing extra fonts

If you have downloaded extra fonts you can mount the folder to the path
`/opt/fonts`. This will ensure that all the .ttf files are copied to the correct
path during initialisation.

```
ie VERSION=2.21.2
docker run -v fonts:/opt/fonts -p 8080:8080 -t kartoza/geoserver:${VERSION}
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
  * `ACTIVATE_ALL_COMMUNITY_EXTENSIONS` : Activates all downloaded community plugins
  * `ACTIVATE_ALL_STABLE_EXTENSIONS` : Activates all stable plugins previously downloaded

**Note:** Before using `ACTIVATE_ALL_STABLE_EXTENSIONS` and `ACTIVATE_ALL_COMMUNITY_EXTENSIONS`
ensure that all prerequisites for those plugins are matched otherwise the container will not start
and errors will result

### Control flow properties

The control flow module manages requests in GeoServer. Instructions on
what each parameter mean can be read from [documentation](http://docs.geoserver.org/latest/en/user/extensions/controlflow/index.html).

* Example default values for the environment variables

    * `REQUEST_TIMEOUT=60`
    * `PARARELL_REQUEST=100`
    * `GETMAP=10`
    * `REQUEST_EXCEL=4`
    * `SINGLE_USER=6`
    * `GWC_REQUEST=16`
    * `WPS_REQUEST=1000/d;30s`

**Note:** You should customise these variables based on the resources available with your GeoServer

### Changing GeoServer password and username

You can pass the environment variables to change it on runtime.
```
GEOSERVER_ADMIN_PASSWORD
GEOSERVER_ADMIN_USER
```

The username and password are reinitialized each time the container starts. If you do not pass the env variables
`GEOSERVER_ADMIN_PASSWORD` the container will generate a new password which is visible in the
startup logs.

**Note:** When upgrading the `GEOSERVER_ADMIN_PASSWORD` and `GEOSERVER_ADMIN_USER` you will
need to mount the volume `settings:/settings` so that the lock-files generated by the `update_password.sh` are
persistent during initialization. See the example in [docker-compose-build](https://github.com/kartoza/docker-geoserver/blob/master/docker-compose-build.yml)

```
docker run --name "geoserver" -e GEOSERVER_ADMIN_USER=kartoza  -e GEOSERVER_ADMIN_PASSWORD=myawesomegeoserver -p 8080:8080 -d -t kartoza/geoserver
```

**Note:** The docker-compose recipe uses the password `myawesomegeoserver`. It is highly
recommended not to run the container in production using these values.

#### Docker secrets

To avoid passing sensitive information in environment variables, `_FILE` can be appended to
some variables to read from files present in the container. This is particularly useful
in conjunction with Docker secrets, as passwords can be loaded from `/run/secrets/<secret_name>` e.g.:

* -e GEOSERVER_ADMIN_PASSWORD_FILE=/run/secrets/<geoserver_pass_secret>

For more information see [https://docs.docker.com/engine/swarm/secrets/](https://docs.docker.com/engine/swarm/secrets/).

Currently, the following environment variables
```
 GEOSERVER_ADMIN_USER
 GEOSERVER_ADMIN_PASSWORD
 S3_USERNAME
 S3_PASSWORD
 TOMCAT_USER
 TOMCAT_PASSWORD
 PKCS12_PASSWORD
 JKS_KEY_PASSWORD
 JKS_STORE_PASSWORD
```
are supported.


## Mounting Configs

You can mount the config file to the path `/settings`. These configs will
be used in favour of the defaults that are available from the [Build data](https://github.com/kartoza/docker-geoserver/tree/master/build_data)
directory

The configs that can be mounted are
* cluster.properties
* controlflow.properties
* embedded-broker.properties
* geowebcache-diskquota-jdbc.xml
* s3.properties
* tomcat-users.xml
* web.xml - for tomcat cors
* epsg.properties - for custom GeoServer EPSG values
* server.xml - for tomcat configurations
* broker.xml
* users.xml - for Geoserver users.
* roles.xml - To define roles users should have in GeoServer


Example
```
 docker run --name "geoserver" -e GEOSERVER_ADMIN_USER=kartoza  -v /data/controlflow.properties:/settings/controlflow.properties -p 8080:8080 -d -t kartoza/geoserver

```

**Note:** The files `users.xml` and `roles.xml` should be mounted together to prevent errors
during container start. Mounting these two files will overwrite `GEOSERVER_ADMIN_PASSWORD` and `GEOSERVER_ADMIN_USER`
### CORS Support

The image ships with CORS support. If you however need to modify the web.xml you
can mount `web.xml` to `/settings/` directory.

## Clustering using JMS Plugin
GeoServer supports clustering using JMS cluster plugin or using the ActiveMQ-broker.

You can read more about how to set up clustering in [kartoza clustering](https://github.com/kartoza/docker-geoserver/blob/master/clustering/README.md)

## Running the Image


### Run (automated using docker-compose)

**Note:** You probably want to use docker-compose for running as it will provide
a repeatable orchestrated deployment system.


We provide a sample ``docker-compose.yml`` file that illustrates
how you can establish a GeoServer + PostGIS.

If you are interested in the backups , add a section in the `docker-compose.yml`
following instructions from [docker-pg-backup](https://github.com/kartoza/docker-pg-backup/blob/master/docker-compose.yml#L23).

If you start the stack using the compose file make sure you log in into GeoServer using username:`admin` and password:`myawesomegeoserver`.

**Note** The username and password are specified in the `.env` file. It is recommended
to change them into something more secure otherwise a strong password is generated.

Please read the ``docker-compose``
[documentation](https://docs.docker.com/compose/) for details on usage and syntax of ``docker-compose`` - it is not covered here.


Once all the services start, test by visiting the GeoServer landing
page in your browser: [http://localhost:8600/geoserver](http://localhost:8600/geoserver).

To run in the background rather, press ``ctrl-c`` to stop the
containers and run again in the background:

```shell
docker-compose up -d
```

**Note:** The ``docker-compose.yml`` **uses host-based volumes** so
when you remove the containers, **all data will be kept**. Using host-based volumes ensures that your data persists between invocations of the compose file. If you need to delete the container data you need to run `docker-compose down -v`.

### Reverse Proxy using NGINX

You can also put Nginx in front of GeoServer to receive the http request and translate it to uwsgi.

A sample `docker-compose-nginx.yml` is provided for running GeoServer and Nginx

```shell
docker-compose -f docker-compose-nginx.yml  up -d
```
Once the services are running GeoServer will be available from

http://localhost/geoserver/web/


### Additional Notes for MacOS M1 Chip

To run the docker image with MacOS M1 Chip, the image needs to be built locally.

- JDK version of “9-jdk17-openjdk-slim-buster “ can work with M1 Chip as it is instructed on "Local build using repository checkout" section, the parameters below needs to be changed in [.env](https://github.com/kartoza/docker-geoserver/blob/master/.env) file and [Dockerfile](https://github.com/kartoza/docker-geoserver/blob/master/Dockerfile)

```
IMAGE_VERSION=9-jdk17-openjdk-slim-buster
JAVA_HOME=/usr/local/openjdk-17
```

 - The change above also requires the removal of some command-line options in [entrypoint.sh](https://github.com/kartoza/docker-geoserver/blob/master/scripts/entrypoint.sh) file. (Since they generate ```Unrecognized VM option 'CMSClassUnloadingEnabled' ``` error and these options are related to JDK10 and lower)

```
-XX:+CMSClassUnloadingEnabled
-XX:+UseG1GC
```

After these changes, the image can be built as instructed.

To run the just-built local image with your docker-compose file, the platform option in the docker-compose file needs to be specified as ```linux/arm64/v8```. Otherwise, it will try to pull the docker image from the docker hub instead of using the local image.

### Reverse Proxy using NGINX

You can also put nginx in front of geoserver to receive http request and translate it to uwsgi.

A sample `docker-compose-nginx.yml` is provided for running geoserver and nginx

```shell
docker-compose -f docker-compose-nginx.yml  up -d
```
Once the services are running GeoServer will be available from

http://localhost/geoserver/web/

## Kubernetes (Helm Charts)

You can run the image in Kubernetes following the [recipe](https://github.com/kartoza/charts/tree/develop/charts/geoserver)


## Contributing to the image
We welcome users who want to contribute  enriching this service. We follow
the git principles and all pull requests should be against the develop branch so that
we can test them and when we are happy we push them to the master branch.

### Upgrading GeoServer Versions
GeoServer releases and bug fixes are done frequently. We provide a helper script `upgrade_geoserver_version.sh`
which can be run to update the respective files which mention GeoServer version. To run this you need to run

```bash
/bin/bash upgrade_geoserver_version.sh ${GS_VERSION} ${GS_NEW_VERSION}
```
**Note:** The script will also push this changes to the current repo, and it is up to the individual running the script
to push the changes to his specific branch of choice and then complete the pull request

## Support

If you require more substantial assistance from [kartoza](https://kartoza.com)  (because our work and interaction on docker-geoserver is pro bono),
please consider taking out a [Support Level Agreeement](https://kartoza.com/en/shop/product/support)
## Credits

* Tim Sutton (tim@kartoza.com)
* Shane St Clair (shane@axiomdatascience.com)
* Alex Leith (alexgleith@gmail.com)
* Admire Nyakudya (admire@kartoza.com)
* Gavin Fleming (gavin@kartoza.com)
