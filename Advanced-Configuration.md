# Table of Contents

- [Advanced Configuration](#advanced-configuration)
  * [Environment Variables](#environment-variables)
    + [Default installed extensions](#default-installed-extensions)
      - [Activate stable extensions during the contain startup](#activate-stable-extensions-during-the-contain-startup)
      - [Activate community extensions during contain startup](#activate-community-extensions-during-contain-startup)
    + [Using sample data](#using-sample-data)
    + [Enable disk quota storage in PostgreSQL backend](#enable-disk-quota-storage-in-postgresql-backend)
      - [Using SSL and Default PostgreSQL SSL certificates (kartoza/postgis backend)](#using-ssl-and-default-postgresql-ssl-certificates--kartoza-postgis-backend-)
      - [Using SSL certificates signed by a certificate authority (kartoza/postgis backend)](#using-ssl-certificates-signed-by-a-certificate-authority--kartoza-postgis-backend-)
    + [Activating JNDI PostgreSQL connector](#activating-jndi-postgresql-connector)
    + [Running under SSL](#running-under-ssl)
    + [Proxy Base URL](#proxy-base-url)
    + [Removing Tomcat extras](#removing-tomcat-extras)
    + [Upgrading the image to use a specific version](#upgrading-the-image-to-use-a-specific-version)
    + [Installing extra fonts](#installing-extra-fonts)
      - [Google Fonts](#google-fonts)
    + [Other Environment variables supported](#other-environment-variables-supported)
    + [Control flow properties](#control-flow-properties)
    + [Changing GeoServer password and username](#changing-geoserver-password-and-username)
      - [Docker secrets](#docker-secrets)
    + [Changing GeoServer deployment context-root](#changing-geoserver-deployment-context-root)
  * [OpenTelemetry and Prometheus JMX Metrics Support](#opentelemetry-and-prometheus-jmx-metrics-support)
    + [Features](#features)
    + [Configuration](#configuration)
    + [Usage Example](#usage-example)
    + [Notes](#notes)
  * [Mounting Configs](#mounting-configs)
    + [Running scripts on container startup.](#running-scripts-on-container-startup)
    + [CORS Support](#cors-support)
  * [Clustering GeoServer](#clustering-geoserver)
    + [JMS Clustering](#jms-clustering)
    + [ActiveMQ-broker](#activemq-broker)
    + [Reverse Proxy using NGINX](#reverse-proxy-using-nginx)
  * [Kubernetes (Helm Charts)](#kubernetes--helm-charts-)

    
# Advanced Configuration

You can customize the deployment using the provided 
environment variables.


## Environment Variables

A full list of environment variables are specified in the [.env](https://github.com/kartoza/docker-geoserver/blob/develop/compose/.env) file

### Default installed extensions

The image activates the [default_stable_extensions](https://github.com/kartoza/docker-geoserver/blob/develop/build_data/plugins/required_plugins.txt) listed below on container start:

-   vectortiles-plugin
-   wps-plugin
-   libjpeg-turbo-plugin
-   control-flow-plugin
-   pyramid-plugin
-   gdal-plugin
-   monitor-plugin
-   inspire-plugin
-   csw-plugin

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
will be enabled : [list of default plugins](https://github.com/kartoza/docker-geoserver/blob/develop/build_data/plugins/required_plugins.txt)

#### Activate stable extensions during the contain startup

The environment variable `STABLE_EXTENSIONS` is used to activate extensions listed in
[stable_plugins](https://sourceforge.net/projects/geoserver/files/GeoServer/3.0.1/extensions/)

**Note:** The plugins listed in the url is of the format `geoserver-3.0.1-wps-plugin.zip`, but the env
variable expects the env to be of the format `wps-plugin`. Always consult the url to see which plugins
are available. The text file [stable_plugins.txt](https://github.com/kartoza/docker-geoserver/blob/master/build_data/plugins/stable_plugins.txt)
contains a curated list of plugins but might be out of date in some cases.

Example

```
ie VERSION=3.0.1
docker run -d -p 8600:8080 --name geoserver -e STABLE_EXTENSIONS=charts-plugin,db2-plugin kartoza/geoserver:${VERSION}

```

You can pass any comma-separated extensions as defined in [stable_plugins](https://sourceforge.net/projects/geoserver/files/GeoServer/3.0.1/extensions/)

#### Activate community extensions during contain startup

The environment variable `COMMUNITY_EXTENSIONS` can be used to activate extensions listed in
[community_plugins](https://build.geoserver.org/geoserver/2.25.x/community-latest/)

**Note:** The plugins listed in the url is of the format `geoserver-2.25-SNAPSHOT-cog-http-plugin.zip `, but the env
variable expects the env to be of the format `cog-http-plugin`. Always consult the url to see which plugins
are available. The text file [community_plugins.txt](https://github.com/kartoza/docker-geoserver/blob/master/build_data/plugins/stable_plugins.txt)
contains a curated list of community plugins but might be out of date in some cases.

Example

```
ie VERSION=3.0.1
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
ie VERSION=3.0.1
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
POSTGRES_JNDI_NAME=${POSTGRES_JNDI_NAME}
```

The `jndiReferenceName` for Postgres (JNDI) stores in GeoServer will be derived from the `POSTGRES_JNDI_NAME` provided. For example, if `POSTGRES_JNDI_NAME=postgres`, set `jndiReferenceName=java:comp/env/jdbc/postgres`.

### Running under SSL

You can use the environment variables to specify whether you want to run the GeoServer under SSL.
Credits to [AtomGraph](https://github.com/AtomGraph/letsencrypt-tomcat) for the solution to run under SSL.

If you set the environment variable `SSL=true` but do not provide the pem files (`fullchain.pem` and `privkey.pem`)
the container will generate self-signed SSL certificates.

```
ie VERSION=3.0.1
docker run -it --name geoserver -e PKCS12_PASSWORD=geoserver -e JKS_KEY_PASSWORD=geoserver -e JKS_STORE_PASSWORD=geoserver -e SSL=true -p 8443:8443 -p 8600:8080 kartoza/geoserver:${VERSION}
```

If you already have your pem files (`fullchain.pem` and `privkey.pem`) you can mount the directory containing your keys as:

```
ie VERSION=3.0.1
docker run -it --name geoserver -v /etc/certs:/etc/certs -e PKCS12_PASSWORD=geoserver -e JKS_KEY_PASSWORD=geoserver -e JKS_STORE_PASSWORD=geoserver -e SSL=true -p 8443:8443 -p 8600:8080 kartoza/geoserver:${VERSION}

```

You can also use a `PFX` file with this image.
Rename your PFX file as certificate.pfx and then mount the folder containing
your pfx file. This will be converted to pem files.

**Note** When using PFX files make sure that the `ALIAS_KEY` you specify as
an environment variable matches the `ALIAS_KEY` that was used when generating
your `PFX` key.

A full list of SSL variables is provided in [SSL Settings](https://github.com/kartoza/docker-geoserver/blob/develop/compose/.env)

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
ie VERSION=3.0.1
docker run -it --name geoserver -e TOMCAT_EXTRAS=true -p 8600:8080 kartoza/geoserver:${VERSION}
```

**Note:** If `TOMCAT_EXTRAS` is set to false, requests to the root webapp ("/") will return HTTP status code 404.
To issue a redirect to the GeoServer webapp ("/geoserver/web") set `ROOT_WEBAPP_REDIRECT=true`

### Upgrading the image to use a specific version

If you are migrating your GeoServer instance, from a lower
version to a higher and do not need to update your master
password, you will need to set the variable `EXISTING_DATA_DIR`.

You can set the env variable `EXISTING_DATA_DIR` to any value i.e.
`EXISTING_DATA_DIR=foo` or `EXISTING_DATA_DIR=false`
When the environment variable is set it will ensure that the password initialization is skipped
during the startup procedure.

### Installing extra fonts

If you have downloaded extra fonts you can mount the folder to the path
`/opt/fonts`. This will ensure that all the `.ttf` or `.otf` files are copied to the correct
path during initialisation. This is useful for styling layers i.e. labeling using specific fonts.

```
ie VERSION=3.0.1
docker run -v fonts:/opt/fonts -p 8080:8080 -t kartoza/geoserver:${VERSION}
```

#### Google Fonts

You can use the environment variable `GOOGLE_FONTS_NAMES` to activate fonts defined in [Google fonts](https://github.com/google/fonts.git)

i.e.

```bash
ie VERSION=3.0.1
docker run -e GOOGLE_FONTS_NAMES=actor,akronim -p 8080:8080 -t kartoza/geoserver:${VERSION}
```

### Other Environment variables supported

You can find a full list of environment variables in [Generic Env variables](https://github.com/kartoza/docker-geoserver/blob/develop/compose/.env)

**Note** The list below is not exhaustive of all values available.
Always consult the `.env` file to check possible values.

-   GEOSERVER_DATA_DIR=`PATH`
-   ENABLE_JSONP=`true or false`
-   MAX_FILTER_RULES=`Any integer`
-   OPTIMIZE_LINE_WIDTH=`false or true`
-   FOOTPRINTS_DATA_DIR=`PATH`
-   GEOWEBCACHE_CACHE_DIR=`PATH`
-   GEOSERVER_ADMIN_PASSWORD=`password`
-   GEOSERVER_ADMIN_USER=`username`
-   GEOSERVER_FILEBROWSER_HIDEFS=`false or true`
-   XFRAME_OPTIONS=`"true"` - Based on [Xframe-options](https://docs.geoserver.org/latest/en/user/production/config.html#x-frame-options-policy)
-   INITIAL_MEMORY=`size`: Initial Memory that Java can allocate, default `2G`
-   MAXIMUM_MEMORY=`size`: Maximum Memory that Java can allocate, default `4G`
-

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

You can additionally pass comma separated values of password i.e.

```bash
GEOSERVER_ADMIN_PASSWORD=myawesomegeoserver,mygeoserver,mysample
GEOSERVER_ADMIN_USER=foo,myadmin,sample
```

If there is a mismatch on number of users and password,
the default creds are used to login.

```bash
GEOSERVER_ADMIN_PASSWORD=geoserver
GEOSERVER_ADMIN_USER=admin
```

Currently, there is no logic to parse passwords with comma separated i.e.

```bash
GEOSERVER_ADMIN_PASSWORD="'myawes,omegeoserver',mygeoserver,mysample"

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

-   -e GEOSERVER_ADMIN_PASSWORD_FILE=/run/secrets/<geoserver_pass_secret>

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

## OpenTelemetry and Prometheus JMX Metrics Support

This image includes optional support for **OpenTelemetry tracing** and **Prometheus JMX metrics exporting** to help with observability and performance monitoring.

### Features

-   **OpenTelemetry Tracing** via the OpenTelemetry Java Agent
-   **Prometheus Metrics Exporting** via JMX Exporter

### Configuration

These features are disabled by default and can be enabled with environment variables:

| Environment Variable      | Default | Description                                      |
| ------------------------- | ------- | ------------------------------------------------ |
| TELEMETRY_TRACING_ENABLED | false   | Enables OpenTelemetry tracing via the Java agent |
| TELEMETRY_METRICS_ENABLED | false   | Enables Prometheus JMX metrics exporter          |
| TELEMETRY_METRICS_PORT    | 12345   | Port exposed for the JMX Prometheus agent        |
| OTEL_VERSION              | v2.17.1 | Version installed of OpenTelemetry agent         |
| JMX_PROMETHEUS_VERSION    | 1.0.1   | Version installed of JMX Prometheus agent        |

### Usage Example

```
docker run -d \
  -e TELEMETRY_TRACING_ENABLED=true \
  -e TELEMETRY_METRICS_ENABLED=true \
  -e TELEMETRY_METRICS_PORT=12345 \
  -p 8080:8080 \
  -p 12345:12345 \
  kartoza/geoserver
```

-   Traces will be exported via the OpenTelemetry Java agent (requires a collector or endpoint to be configured externally via `OTEL_` env vars. Read more about [`OTLP Exporter Configuration` here](https://opentelemetry.io/docs/languages/sdk-configuration/otlp-exporter/)).
-   Metrics will be exposed on the specified port in Prometheus scrape-compatible format.

### Notes

-   For advanced configuration, you can mount your own `/jmx/config.yaml`.

## Mounting Configs

You can mount the config file to the path `/settings`. These configs will
be used in favour of the defaults that are available from the [Build data](https://github.com/kartoza/docker-geoserver/tree/master/build_data)
directory

The configs that can be mounted are

-   cluster.properties
-   controlflow.properties
-   embedded-broker.properties
-   geowebcache-diskquota-jdbc.xml
-   s3.properties
-   tomcat-users.xml
-   web.xml - for tomcat cors
-   epsg.properties - for custom GeoServer EPSG values
-   server.xml - for tomcat configurations
-   broker.xml
-   users.xml - for Geoserver users.
-   roles.xml - To define roles users should have in GeoServer
-   logging.properties - Controls logging to sdtout parameters

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



### Reverse Proxy using NGINX

You can also put Nginx in front of GeoServer to receive the http request and translate it to uwsgi.

A sample `docker-compose-nginx.yml` is provided for running GeoServer and Nginx

```shell
docker-compose -f docker-compose-nginx.yml  up -d
```

Once the services are running GeoServer will be available from

http://localhost/geoserver/web/

## Kubernetes (Helm Charts)

You can run the image in Kubernetes following the [recipe](https://github.com/kartoza/charts/tree/develop/charts/geoserver)


