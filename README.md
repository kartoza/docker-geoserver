# docker-geoserver

A simple docker container that runs Geoserver influenced by this docker
recipe: https://github.com/eliotjordan/docker-geoserver/blob/master/Dockerfile

**Note:** We recommend using ``apt-cacher-ng`` to speed up package fetching -
you should configure the host for it in the provided 71-apt-cacher-ng file.

## Getting the image

There are various ways to get the image onto your system:

The preferred way (but using most bandwidth for the initial image) is to
get our docker trusted build like this:


```shell
docker pull kartoza/geoserver
```

To build the image yourself without apt-cacher-ng (also consumes more bandwidth
since deb packages need to be refetched each time you build) do:

```shell
docker build -t kartoza/geoserver git://github.com/kartoza/docker-geoserver
```

To build with apt-cacher-ng (and minimised download requirements) do you need to
clone this repo locally first and modify the contents of 71-apt-cacher-ng to
match your cacher host. Then build using a local url instead of directly from
github.

```shell
git clone git://github.com/kartoza/docker-geoserver
```

Now edit ``71-apt-cacher-ng`` then do:

```shell
docker build -t kartoza/geoserver .
```

### Building with Oracle JDK

To replace OpenJDK Java with the Oracle JDK, set build-arg `ORACLE_JDK=true`:

```shell
docker build --build-arg ORACLE_JDK=true -t kartoza/geoserver .
```

Alternatively, you can download the Oracle JDK 7 Linux x64 tar.gz currently in use by
[webupd8team's Oracle JDK installer](https://launchpad.net/~webupd8team/+archive/ubuntu/java/+packages)
(usually the latest version available from Oracle) and place it in `resources` before building.

To enable strong cryptography when using the Oracle JDK (recommended), download the
[Oracle Java policy jar zip](http://docs.geoserver.org/latest/en/user/production/java.html#oracle-java)
for the correct JDK version and place it at `resources/jce_policy.zip` before building.

### Building with plugins

To build a GeoServer image with plugins (e.g. SQL Server plugin, Excel output plugin),
download the plugin zip files from the GeoServer download page and put them in
`resources/plugins` before building. You should also download the matching version
GeoServer WAR zip file to `resources/geoserver.zip`.

### Removing Tomcat extras during build

To remove Tomcat extras including docs, examples, and the manager webapp, set the
`TOMCAT_EXTRAS` build-arg to `false`:

```shell
docker build --build-arg TOMCAT_EXTRAS=false -t kartoza/geoserver .
```

### Building with file system overlays (advanced)

The contents of `resources/overlays` will be copied to the image file system
during the build. For example, to include a static Tomcat `setenv.sh`,
create the file at `resources/overlays/usr/local/tomcat/bin/setenv.sh`.

You can use this functionality to write a static GeoServer directory to
`/opt/geoserver/data_dir`, include additional jar files, and more.

Overlay files will overwrite existing destination files, so be careful!

## Run

You probably want to also have postgis running too. To create a running 
container do:

```shell
docker run --name "postgis" -d -t kartoza/postgis:9.4-2.1
docker run --name "geoserver"  --link postgis:postgis -p 8080:8080 -d -t kartoza/geoserver
```

You can also use the following environment variables to pass a 
user name and password. To postgis:

* -e USERNAME=<PGUSER> 
* -e PASS=<PGPASSWORD>

These will be used to create a new superuser with
your preferred credentials. If these are not specified then the postgresql 
user is set to 'docker' with password 'docker'.

There is also a convenience run script that will setup a postgis container
and a geoserver container in the ``run.sh`` script for this repository.

**Note:** The default geoserver user is 'admin' and the password is 'geoserver'.
We highly recommend changing these as soon as you first log in.

## Storing data on the host rather than the container.


Docker volumes can be used to persist your data.

```shell
mkdir -p ~/geoserver_data
docker run -d -v $HOME/geoserver_data:/opt/geoserver/data_dir kartoza/geoserver
```

You need to ensure the ``geoserver_data`` directory has sufficient permissions
for the docker process to read / write it.

## Setting Tomcat properties

To set Tomcat properties such as maximum heap memory size, create a `setenv.sh` file such as:

```shell
JAVA_OPTS="$JAVA_OPTS -Xmx1536M -XX:MaxPermSize=756M"
JAVA_OPTS="$JAVA_OPTS -Djava.awt.headless=true -XX:+UseConcMarkSweepGC -XX:+CMSClassUnloadingEnabled"
```

Then pass the `setenv.sh` file as a volume at `/usr/local/tomcat/bin/setenv.sh` when running:

```shell
docker run -d -v $HOME/setenv.sh:/usr/local/tomcat/bin/setenv.sh kartoza/geoserver
```

## Credits

* Tim Sutton (tim@kartoza.com)
* Shane St Clair (shane@axiomdatascience.com)
* Alex Leith (alexgleith@gmail.com)
