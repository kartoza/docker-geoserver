# Table of Contents
- [Kartoza docker-geoserver](#kartoza-docker-geoserver)
  * [Getting the image](#getting-the-image)
    + [Pulling from Dockerhub](#pulling-from-dockerhub)
    + [Building the image](#building-the-image)
    + [Local build using repository checkout](#local-build-using-repository-checkout)
    + [Building with a specific version of  Tomcat](#building-with-a-specific-version-of--tomcat)
    + [Building on Windows](#building-on-windows)
  * [Environment Variables](#environment-variables)
    + [Default installed extensions](#default-installed-extensions)
      - [Activate stable extensions during contain startup](#activate-stable-extensions-during-contain-startup)
      - [Activate community extensions during contain startup](#activate-community-extensions-during-contain-startup)
    + [Using sample data](#using-sample-data)
    + [Enable disk quota storage in PostgreSQL backend](#enable-disk-quota-storage-in-postgresql-backend)
      - [Using SSL and Default PostgreSQL ssl certificates (kartoza/postgis backend)](#using-ssl-and-default-postgresql-ssl-certificates--kartoza-postgis-backend-)
      - [Using SSL certificates signed by a certificate authority (kartoza/postgis backend)](#using-ssl-certificates-signed-by-a-certificate-authority--kartoza-postgis-backend-)
    + [Activating JNDI PostgreSQL connector](#activating-jndi-postgresql-connector)
    + [Running under SSL](#running-under-ssl)
    + [Proxy Base URL](#proxy-base-url)
    + [Removing Tomcat extras](#removing-tomcat-extras)
    + [Upgrading image to use a specific version](#upgrading-image-to-use-a-specific-version)
    + [Installing extra fonts](#installing-extra-fonts)
    + [Other Environment variables supported](#other-environment-variables-supported)
    + [Control flow properties](#control-flow-properties)
    + [Changing GeoServer password and username](#changing-geoserver-password-and-username)
      - [Docker secrets](#docker-secrets)
    + [Changing GeoServer deployment context-root](#changing-geoserver-deployment-context-root)
  * [Mounting Configs](#mounting-configs)
    + [CORS Support](#cors-support)
  * [Clustering using JMS Plugin](#clustering-using-jms-plugin)
  * [Running the Image](#running-the-image)
    + [Run (automated using docker-compose)](#run--automated-using-docker-compose-)
    + [Reverse Proxy using NGINX](#reverse-proxy-using-nginx)
  * [Kubernetes (Helm Charts)](#kubernetes--helm-charts-)
  * [Contributing to the image](#contributing-to-the-image)
    + [Upgrading GeoServer Versions](#upgrading-geoserver-versions)
      - [Upgrade extensions files](#upgrade-extensions-files)
      - [Run upgrade helper script](#run-upgrade-helper-script)
  * [Support](#support)
  * [Credits](#credits)

# Kartoza docker-geoserver

* A simple docker container that runs GeoServer influenced by this [docker recipe](https://github.com/eliotjordan/docker-geoserver/blob/master/Dockerfile).
* The image has environment variables that allow users to configure GeoServer based on [running-in-production](https://docs.geoserver.org/latest/en/user/production/index.html)
* The image uses [kartoza/postgis](https://github.com/kartoza/docker-postgis/) as a
 database backend. You can use any other PostgreSQL image
but adjust the environment variables accordingly.


## Getting the image

There are various ways to get the image onto your system:

   * Pulling from Dockerhub
   * Local build using docker-compose

### Pulling from Dockerhub

The preferred way (but using the most bandwidth for the initial image) is to
get our docker-trusted build like this:

``` shell
VERSION=2.26.1
docker pull kartoza/geoserver:$VERSION
```
**Note** Although the images are tagged and backed by unit tests
it is recommended to use tagged versions with dates i.e. 
`kartoza/geoserver:$VERSION--v2024.03.31`.The first date available
from [dockerhub](https://hub.docker.com/repository/docker/kartoza/geoserver/tags?page=1&ordering=last_updated)
It would be the first version for that series. Successive builds that fix [issues](https://github.com/kartoza/docker-geoserver/issues) 
tend to override the tagged images and also produce dated images.

### Building the image


### Local build using repository checkout

To build yourself with a local checkout using the docker-compose-build.yml:

1. Clone the GitHub repository:

   ``` shell
   git clone https://github.com/kartoza/docker-geoserver
   ```
2. Edit the [build arguments](https://github.com/kartoza/docker-geoserver/blob/master/.env) in the `.env` file:

3. Build the container and spin up the services
   ``` shell
   cd docker-geoserver
   docker-compose -f docker-compose-build.yml up -d geoserver-prod --build
   ```


### Building with a specific version of  Tomcat

To build using a specific tagged release of the tomcat image set the
`IMAGE_VERSION` build arg: 
See the [dockerhub tomcat](https://hub.docker.com/_/tomcat/)
for available tags.

```
VERSION=2.26.1
IMAGE_VERSION=9.0.91-jdk11-temurin-focal
docker build --build-arg IMAGE_VERSION=${IMAGE_VERSION} --build-arg GS_VERSION=${VERSION} -t kartoza/geoserver:${VERSION} .
```

For some recent builds, it is necessary to set the JAVA_PATH as well (e.g. Apache Tomcat/9.0.36)
```
docker build --build-arg IMAGE_VERSION=9.0.91-jdk11-temurin-focal --build-arg JAVA_HOME=/usr/local/openjdk-11/bin/java --build-arg GS_VERSION=2.26.1 -t kartoza/geoserver:2.26.1 .
```

**Note:** Please check the [GeoServer documentation](https://docs.geoserver.org/stable/en/user/production/index.html) 
to see which Tomcat versions are supported.

The current build uses the base image `tomcat:9.0.91-jdk11-temurin-focal` because of the dependency on
`libgdal-java`. The tomcat base images > focal will not
have the java bindings for the [GDAL plugin](https://osgeo-org.atlassian.net/browse/GEOT-7412?focusedCommentId=84733)
hence the container will not support the gdal plugin working if you build using base image > focal.

### Building on Windows

These instructions detail the recommended process for reliably building this on Windows.

Prerequisites - You will need to have this software preinstalled on the system being used to build the Geoserver image:

   * Docker Desktop with WSL2
   * [Java JDK](https://jdk.java.net/)
   * [Conda](https://conda.io/)
   * GDAL (Install with Conda)

Add the conda-forge channel to your conda installation:

```bash
conda config --add channels conda-forge
```

Now create a new conda environment with GDAL, installed from conda. Ensure that this environment is active when running
the docker build, e.g.

```bash
conda create -n geoserver-build -c conda-forge python gdal
conda activate geoserver-build
```

Modify the `.env` with the appropriate environment variables. It is recommended that short paths (without whitespace) 
are used with forward slashes to prevent errors. You can get the current Java command short path with PowerShell:

```bash
(New-Object -ComObject Scripting.FileSystemObject).GetFile((get-command java).Source).ShortPath
```

Running the above command should yield a path similar to `C:/PROGRA~1/Java/JDK-15~1.2/bin/java.exe`, which can be 
assigned to `JAVA_HOME` in the environment configuration file.

Then run the docker build commands. If you encounter issues, you may want to ensure that you try to build the image 
without the cache and then run docker up separately:

```bash
docker-compose -f docker-compose-build.yml build --force-rm --no-cache
docker-compose -f docker-compose-build.yml up -d
```

## Environment Variables
A full list of environment variables are specified in the [.env](https://github.com/kartoza/docker-geoserver/blob/develop/.env) file

### Default installed extensions

The image activates the [default_stable_extensions](https://github.com/kartoza/docker-geoserver/blob/develop/build_data/required_plugins.txt) listed below on container start:

* vectortiles-plugin
* wps-plugin
* libjpeg-turbo-plugin
* control-flow-plugin
* pyramid-plugin
* gdal-plugin
* monitor-plugin
* inspire-plugin
* csw-plugin

If you wish to exclude any of the default activated plugins you will need to set
```bash
ACTIVE_EXTENSIONS=${Default_extension} - skipped_default_extension
```

i.e. 
```
ACTIVE_EXTENSIONS=control-flow-plugin,csw-iso-plugin,csw-plugin,gdal-plugin,inspire-plugin,monitor-plugin,pyramid-plugin,vectortiles-plugin,wps-plugin
```
will skip activating libjpeg-turbo-plugin.

The variable `ACTIVE_EXTENSIONS` is used to specify a set of plugins to enable, if left empty or unset the following 
will be enabled : [list of default plugins](https://github.com/kartoza/docker-geoserver/blob/develop/build_data/required_plugins.txt)

####  Activate stable extensions during the contain startup

The environment variable `STABLE_EXTENSIONS` is used to activate extensions listed in
[stable_plugins](https://sourceforge.net/projects/geoserver/files/GeoServer/2.26.1/extensions/)

**Note:** The plugins listed in the url is of the format `geoserver-2.26.1-wps-plugin.zip`, but the env
variable expects the env to be of the format `wps-plugin`. Always consult the url to see which plugins 
are available. The text file [stable_plugins.txt](https://github.com/kartoza/docker-geoserver/blob/master/build_data/stable_plugins.txt)
contains a curated list of plugins but might be out of date in some cases.

Example

```
ie VERSION=2.26.1
docker run -d -p 8600:8080 --name geoserver -e STABLE_EXTENSIONS=charts-plugin,db2-plugin kartoza/geoserver:${VERSION}

```
You can pass any comma-separated extensions as defined in [stable_plugins](https://sourceforge.net/projects/geoserver/files/GeoServer/2.26.1/extensions/)

####  Activate community extensions during contain startup

The environment variable `COMMUNITY_EXTENSIONS` can be used to activate extensions listed in
[community_plugins](https://build.geoserver.org/geoserver/2.25.x/community-latest/)

**Note:** The plugins listed in the url is of the format `geoserver-2.25-SNAPSHOT-cog-http-plugin.zip `, but the env
variable expects the env to be of the format `cog-http-plugin`. Always consult the url to see which plugins 
are available. The text file [community_plugins.txt](https://github.com/kartoza/docker-geoserver/blob/master/build_data/stable_plugins.txt)
contains a curated list of community plugins but might be out of date in some cases.

Example

```
ie VERSION=2.26.1
docker run -d -p 8600:8080 --name geoserver -e COMMUNITY_EXTENSIONS=gwc-sqlite-plugin,ogr-datastore-plugin kartoza/geoserver:${VERSION}
```

The image ships with extension zip files pre-downloaded. You can pass an additional environment variable
`FORCE_DOWNLOAD_COMMUNITY_EXTENSIONS=true` to download the latest community extensions during the initialisation of the container.

**Note:** If you experience an issue running community extensions
please check upstream before reporting the issue here. If an extension is no longer available you can build the extensions
following the guidelines from [GeoServer develop guidelines](https://docs.geoserver.org/latest/en/developer/maven-guide/index.html#building-extensions)

### Using sample data

The image ships with sample data. This can be used to familiarize yourself with GeoServer. This is not activated by default. You can activate it using the environment variable `boolean SAMPLE_DATA`.

```
ie VERSION=2.26.1
docker run -d -p 8600:8080 --name geoserver -e SAMPLE_DATA=true kartoza/geoserver:${VERSION}
```

### Enable disk quota storage in PostgreSQL backend

GeoServer defaults to using HSQL datastore for configuring disk quota. You can alternatively use 
a PostgreSQL backend as a disk quota store. When using a PostgreSQL backend, you need to have a running instance of the database which can be connected to. 

If you want to test it locally with docker-compose postgres db you need to specify these env variables:
```bash
DB_BACKEND=POSTGRES               
HOST=db                          
POSTGRES_PORT=5432                
POSTGRES_DB=gwc                   
POSTGRES_USER=${POSTGRES_USER}    
POSTGRES_PASS=${POSTGRES_PASS}    
SSL_MODE=allow                    
POSTGRES_SCHEMA=public           
DISK_QUOTA_SIZE=5 
```

#### Using SSL and Default PostgreSQL SSL certificates (kartoza/postgis backend)

When the environment variable `FORCE_SSL=TRUE` is set for the database container you
will need to set `SSL_MODE=allow` in the GeoServer container.

#### Using SSL certificates signed by a certificate authority (kartoza/postgis backend)

When the environment variable `FORCE_SSL=TRUE` is set for the database container you
will need to set `SSL_MODE` to either `verify-full` or `verify-ca`
for the GeoServer container. You will also need to mount the SSL certificates
you have done in the DB.

In the GeoServer container, the certificates need to be mounted to the folder
specified by the certificate directory ${CERT_DIR}

```
SSL_CERT_FILE=/etc/certs/fullchain.pem
SSL_KEY_FILE=/etc/certs/privkey.pem
SSL_CA_FILE=/etc/certs/root.crt
```

### Activating JNDI PostgreSQL connector
When defining vector stores you can use the JNDI pooling. To activate this, adjust the following environment 
variable `POSTGRES_JNDI=TRUE`. By default, the environment the 
variable is set to `FALSE`. Additionally, you will need to 
define parameters to connect to an existing PostgreSQL database

```
POSTGRES_JNDI=TRUE
HOST=${POSTGRES_HOSTNAME}
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASS=${POSTGRES_PASS}
```

When defining the parameters for the store in GeoServer you will need to set
`jndiReferenceName=java:comp/env/jdbc/postgres`

### Running under SSL
You can use the environment variables to specify whether you want to run the GeoServer under SSL.
Credits to [AtomGraph](https://github.com/AtomGraph/letsencrypt-tomcat) for the solution to run under SSL.


If you set the environment variable `SSL=true` but do not provide the pem files (`fullchain.pem` and `privkey.pem`)
the container will generate self-signed SSL certificates.

```
ie VERSION=2.26.1
docker run -it --name geoserver -e PKCS12_PASSWORD=geoserver -e JKS_KEY_PASSWORD=geoserver -e JKS_STORE_PASSWORD=geoserver -e SSL=true -p 8443:8443 -p 8600:8080 kartoza/geoserver:${VERSION}
```

If you already have your pem files (`fullchain.pem` and `privkey.pem`) you can mount the directory containing your keys as:

```
ie VERSION=2.26.1
docker run -it --name geoserver -v /etc/certs:/etc/certs -e PKCS12_PASSWORD=geoserver -e JKS_KEY_PASSWORD=geoserver -e JKS_STORE_PASSWORD=geoserver -e SSL=true -p 8443:8443 -p 8600:8080 kartoza/geoserver:${VERSION}

```

You can also use a `PFX` file with this image.
Rename your PFX file as certificate.pfx and then mount the folder containing
your pfx file. This will be converted to pem files.

**Note** When using PFX files make sure that the `ALIAS_KEY` you specify as
an environment variable matches the `ALIAS_KEY` that was used when generating
your `PFX` key.

A full list of SSL variables is provided in [SSL Settings](https://github.com/kartoza/docker-geoserver/blob/develop/.env)


### Proxy Base URL

For the server to report a full proxy base URL, you need to pass
the following env variable i.e.

```
HTTP_PROXY_NAME
HTTP_PROXY_PORT
```

If you are running GeoServer under SSL with reverse proxy i.e. nginx you will need
to set the following env variables

Example below:

```bash
HTTP_PROXY_NAME=foo.org
HTTP_SCHEME=https
```

> Note: if you're running this on Fargate behind a load balancer that already terminates SSL, you only need `HTTP_SCHEME=https`.

This will prevent the login form from sending insecure http post requests as experienced
in [login issue](https://github.com/kartoza/docker-geoserver/issues/293)

For SSL-based connections, the env variables are:

```
HTTPS_PROXY_NAME
HTTPS_PROXY_PORT
HTTPS_SCHEME
```

### Removing Tomcat extras

To include Tomcat extras including docs, examples, and the manager web app, set the
`TOMCAT_EXTRAS` environment variable to `true`:

**Note:** If `TOMCAT_EXTRAS` is set to true then you should configure `TOMCAT_PASSWORD`
to use a strong password otherwise a randomly generated password is used.

```
ie VERSION=2.26.1
docker run -it --name geoserver -e TOMCAT_EXTRAS=true -p 8600:8080 kartoza/geoserver:${VERSION}
```

**Note:** If `TOMCAT_EXTRAS` is set to false, requests to the root webapp ("/") will return HTTP status code 404. 
To issue a redirect to the GeoServer webapp ("/geoserver/web") set `ROOT_WEBAPP_REDIRECT=true`

### Upgrading the image to use a specific version
If you are migrating your GeoServer instance, from a lower 
version to a higher and do not need to update your master 
password, you will need to set the variable `EXISTING_DATA_DIR`. 

You can set the  env variable `EXISTING_DATA_DIR` to any value i.e.
`EXISTING_DATA_DIR=foo` or `EXISTING_DATA_DIR=false` 
When the environment variable is set it will ensure that the password initialization is skipped
during the startup procedure.

### Installing extra fonts

If you have downloaded extra fonts you can mount the folder to the path
`/opt/fonts`. This will ensure that all the `.ttf` or `.otf` files are copied to the correct
path during initialisation. This is useful for styling layers i.e. labeling using specific fonts.

```
ie VERSION=2.26.1
docker run -v fonts:/opt/fonts -p 8080:8080 -t kartoza/geoserver:${VERSION}
```

#### Google Fonts
You can use the environment variable `GOOGLE_FONTS_NAMES` to activate fonts defined in [Google fonts](https://github.com/google/fonts.git)

i.e.

```bash
ie VERSION=2.26.1
docker run -e GOOGLE_FONTS_NAMES=actor,akronim -p 8080:8080 -t kartoza/geoserver:${VERSION}
```

### Other Environment variables supported

You can find a full list of environment variables in [Generic Env variables](https://github.com/kartoza/docker-geoserver/blob/develop/.env)

**Note** The list below is not exhaustive of all values available.
Always consult the `.env` file to check possible values. 

* GEOSERVER_DATA_DIR=`PATH`
* ENABLE_JSONP=`true or false`
* MAX_FILTER_RULES=`Any integer`
* OPTIMIZE_LINE_WIDTH=`false or true`
* FOOTPRINTS_DATA_DIR=`PATH`
* GEOWEBCACHE_CACHE_DIR=`PATH`
* GEOSERVER_ADMIN_PASSWORD=`password`
* GEOSERVER_ADMIN_USER=`username`
* GEOSERVER_FILEBROWSER_HIDEFS=`false or true`
* XFRAME_OPTIONS=`"true"` - Based on [Xframe-options](https://docs.geoserver.org/latest/en/user/production/config.html#x-frame-options-policy)
* INITIAL_MEMORY=`size`: Initial Memory that Java can allocate, default `2G`
* MAXIMUM_MEMORY=`size`: Maximum Memory that Java can allocate, default `4G`
* 


### Control flow properties

The control flow module manages requests in GeoServer. Instructions on
what each parameter means can be read from [documentation](http://docs.geoserver.org/latest/en/user/extensions/controlflow/index.html).

The following env variables can be set

```bash
REQUEST_TIMEOUT=60
PARALLEL_REQUEST=100
GETMAP=10
REQUEST_EXCEL=4
SINGLE_USER=6
GWC_REQUEST=16
WPS_REQUEST=1000/d;30s
```

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
 S3_SERVER_URL
 S3_ALIAS
 TOMCAT_USER
 TOMCAT_PASSWORD
 PKCS12_PASSWORD
 JKS_KEY_PASSWORD
 JKS_STORE_PASSWORD
 TOMCAT_USER
```
are supported.

### Changing GeoServer deployment context-root

You can pass the environment variable to change the context-root at runtime,
example:
```
GEOSERVER_CONTEXT_ROOT=my-geoserver
```

The example above will deploy Geoserver at https://host/my-geoserver instead of
the default location at https://host/geoserver.

It is also possible to do a nested context-root. [Apache Tomcat nested 
context-roots are specified via #](https://octopus.com/blog/defining-tomcat-context-paths#conclusion).
```
GEOSERVER_CONTEXT_ROOT=foo#my-geoserver
```
The example above will deploy Geoserver at https://host/foo/my-geoserver 
instead of the default location at https://host/geoserver.

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
* logging.properties - Controls logging to sdtout parameters


Example
```
 docker run --name "geoserver" -e GEOSERVER_ADMIN_USER=kartoza  -v /data/controlflow.properties:/settings/controlflow.properties -p 8080:8080 -d -t kartoza/geoserver
```

**Note:** The files `users.xml` and `roles.xml` should be mounted together to prevent errors
during container start. Mounting these two files will overwrite `GEOSERVER_ADMIN_PASSWORD` and `GEOSERVER_ADMIN_USER`

### Running scripts on container startup.

You can run some bash script to correct some missing dependencies i.e. in 
community extension like [cluster issue](https://github.com/kartoza/docker-geoserver/issues/514)

```bash
-v ./run.sh:/docker-entrypoint-geoserver.d/run.sh
```

### CORS Support

The image ships with CORS support. If you however need to modify the web.xml you
can mount `web.xml` to `/settings/` directory.

## Clustering GeoServer

### JMS Clustering

GeoServer supports clustering using the JMS cluster plugin.

You can read more about how to set up clustering in [kartoza clustering](https://github.com/kartoza/docker-geoserver/blob/master/clustering/README.md)

### ActiveMQ-broker

You can use the `docker-compose-external.yml` in the clustering folder.

## Running the Image


### Run (automated using docker-compose)

We provide a sample ``docker-compose.yml`` file that illustrates
how you can establish a GeoServer + PostGIS.

If you are interested in the backups, add a section in the `docker-compose.yml`
following instructions from [docker-pg-backup](https://github.com/kartoza/docker-pg-backup/blob/master/docker-compose.yml#L23).

Start the services using:
``` shell
docker-compose up -d
```

**Note** The username and password are specified in the `.env` file. It is recommended
to change them into something more secure. If you do not pass the
env `GEOSERVER_ADMIN_PASSWORD` the container generates a 
random string which will be your password. This is visible from 
the startup logs.

Once all the services start, test by visiting the GeoServer landing
page in your browser: [http://localhost:8600/geoserver](http://localhost:8600/geoserver).

### Reverse Proxy using NGINX

You can also put Nginx in front of GeoServer to receive the http request and translate it to uwsgi.

A sample `docker-compose-nginx.yml` is provided for running GeoServer and Nginx

``` shell
docker-compose -f docker-compose-nginx.yml  up -d
```
Once the services are running GeoServer will be available from

http://localhost/geoserver/web/


## Kubernetes (Helm Charts)

You can run the image in Kubernetes following the [recipe](https://github.com/kartoza/charts/tree/develop/charts/geoserver)


## Contributing to the image
We welcome users who want to contribute to enriching this service. We follow
the git principles and all pull requests should be against the develop branch so that
we can test them and when we are happy we push them to the master branch.

### Upgrading GeoServer Versions
GeoServer releases and bug fixes are done frequently. We provide a helper script 
`upgrade_geoserver_version.sh` which can be run to update the 
respective files which mention the GeoServer version. To upgrade to
a new version involves:

1. Run the upgrade script that updates some env variables.
2. Update the [github workflows](https://github.com/kartoza/docker-geoserver/tree/develop/.github/workflows) files to.
match the specific versions.

#### Run upgrade helper script


```bash
/bin/bash upgrade_geoserver_version.sh ${GS_VERSION} ${GS_NEW_VERSION}
```
**Note:** The script will also push these changes to the current repo, and it is up to the individual running the script
to push the changes to his specific branch of choice and then complete the pull request

## Support
When reporting issues especially related to installed extensions (community and stable) please refer to the [GeoServer Issue page](https://osgeo-org.atlassian.net/jira/software/c/projects/GEOS/issues)
to see if there are no issues reported there. We rely on the GeoServer community to resolve upstream
issues. For urgent upstream problems, you will need to get paid support
from the developers in [GeoServer](https://geoserver.org/). 

### Security Vulnerabilities
The published image uses [Trivy](https://trivy.dev/latest/) to scan vulnerabilities. These vulnerabilities
are listed in the [security section](https://github.com/kartoza/docker-geoserver/security/code-scanning).
You can also use other tools to scan the image for vulnerabilities i.e. `docker scan`. 
The images also inherit vulnerabilities from the base images i.e. [tomcat:9.0.91-jdk11-temurin-focal](https://hub.docker.com/_/tomcat/tags?name=9.0.91-jdk11-temurin-focal).
So when reporting please vulnerabilities please try to distinguish them from the following:
* Base image vulnerabilities - These should be reported in the upstream tomcat repository
and if any fix is applied, we will have to build a new image using a newer image tag.
* Packages installed with these images i.e. gosu. These should be reported as an
issue in this repository and should be tagged with the `security` label.
* Vulnerabilities directly related to libs installed with the GeoServer application, these 
should be reported upstream following the guidelines from [upstream geoserver](https://github.com/geoserver/geoserver/blob/main/SECURITY.md)

Other platforms where users can ask questions and get assistance are listed below:
* [Stack Exchange](https://stackexchange.com/)
* [GeoServer Mailing lists](https://sourceforge.net/projects/geoserver/lists/geoserver-users)
* [GeoServer Commercial Support](https://geoserver.org/support/)


If you require more substantial assistance from [kartoza](https://kartoza.com)  (because our work and interaction on 
docker-geoserver is pro bono), please consider taking out a [Support Level Agreeement](https://kartoza.com/en/shop/product/support)
## Credits

* Tim Sutton (tim@kartoza.com)
* Shane St Clair (shane@axiomdatascience.com)
* Alex Leith (alexgleith@gmail.com)
* Admire Nyakudya (addloe@gmail.com)
* Gavin Fleming (gavin@kartoza.com)
