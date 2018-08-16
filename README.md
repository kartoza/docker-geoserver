# docker-geoserver

A simple docker container that runs Geoserver influenced by this docker
recipe: https://github.com/eliotjordan/docker-geoserver/blob/master/Dockerfile

## Getting the image

There are various ways to get the image onto your system:

The preferred way (but using most bandwidth for the initial image) is to
get our docker trusted build like this:


```shell
docker pull kartoza/geoserver
```

### Pre-downloading files

Inspect downloads.sh to confirm which files you want, then run `.downloads.sh.`
Ensure you install maven on the host so that you can build the community modules `sudo apt-get install -y maven`
Also ensure that you have the JAVA_HOME variable set on the host.

If you don't make changes it will download Oracle Java and various Oracle and Geoserver extensions that will be used during the Docker build. 

### Setting Tomcat properties during build

The  Tomcat properties such as maximum heap memory size are included in the Dockerfile. You need to change them 
them before building the image in accordance to the resources available on your server:

You can change the variables based on [geoserver container considerations](http://docs.geoserver.org/stable/en/user/production/container.html)

To build yourself with a local checkout:

```shell
git clone git://github.com/kartoza/docker-geoserver
cd docker-geoserver
./build.sh
```


### Building with Oracle JDK

To replace OpenJDK Java with the Oracle JDK, set build-arg `ORACLE_JDK=true`:

```shell
#Ensure you have maven installed and have set the JAVA HOME env to ensure  building geoserver community modules
./download.sh
docker build --build-arg ORACLE_JDK=true --build-arg GS_VERSION=2.13.0 -t kartoza/geoserver .
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
GeoServer WAR zip file to `resources/geoserver-${VERSION}.zip` where ${VERSION} can be 2.13.0 or any other version you need to build.

### Removing Tomcat extras during build

To remove Tomcat extras including docs, examples, and the manager webapp, set the
`TOMCAT_EXTRAS` build-arg to `false`:

```shell
#Ensure you have maven installed and have set the JAVA HOME env to ensure  building geoserver community modules
./download.sh
docker build --build-arg TOMCAT_EXTRAS=false --build-arg GS_VERSION=2.13.0 -t kartoza/geoserver .
```

### Building with file system overlays (advanced)

The contents of `resources/overlays` will be copied to the image file system
during the build. For example, to include a static Tomcat `setenv.sh`,
create the file at `resources/overlays/usr/local/tomcat/bin/setenv.sh`.

You can use this functionality to write a static GeoServer directory to
`/opt/geoserver/data_dir`, include additional jar files, and more.

Overlay files will overwrite existing destination files, so be careful!

## Run (manual docker commands)

**Note:** You probably want to use docker-compose for running as it will provide
a repeatable orchestrated deployment system.

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

**Note:** The default geoserver user is 'admin' and the password is 'geoserver'.
We highly recommend changing these as soon as you first log in.

## Run (automated using docker-compose)

We provide a sample ``docker-compose.yml`` file that illustrates
how you can establish a GeoServer + Postgis orchestrated environment
with nightly backups that are synchronised to your backup server
via btsync.

If you are **not** interested in the backups and btsync options, comment 
out those services in the ``docker-compose.yml`` file.

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
cp btsync-db.env.EXAMPLE btsync-db.env
cp btsync-media.env.EXAMPLE btsync-media.env
```

Then edit the two env files, placing your Read/Write resilio keys
in the place provided.


To run the example do:

```
docker-compose up
```

Which will run everything in the foreground giving you the opportunity
to peruse logs and see that everything spins up nicely.

Once all services are started, test by visiting the GeoServer landing
page in your browser: [http://localhost:8600/geoserver](http://localhost:8600/geoserver).

To run in the background rather, press ``ctrl-c`` to stop the
containers and run again in the background:

```
docker-compose up -d
```

**Note:** The ``docker-compose.yml`` **does not use persistent storage** so
when you remove the containers, **all data will be lost**. Either set up 
btsync (and test to verify that your backups are working, we take 
**no responsibiliy** if the examples provided here do not produce 
a reliable backup system), or use host based volumes (you will need 
to modify the ``docker-compose.yml``` example to do this) so that
your data persists between invocations of the compose file.

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
(created by the nightly backup tool in the stack), use (Resilio 
sync)[https://www.resilio.com/] to create two Read/Write keys:

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
it from geonode site as indicated below:

```shell
#!/bin/sh
# where GS_VERSION is the version of the geoserver installed
unzip resources/geoserver-${GS_VERSION}.zip -d /tmp/geoserver-${GS_VERSION}
unzip /tmp/geoserver-${GS_VERSION}/geoserver.war -d /tmp/geoserver-${GS_VERSION}/geoserver
mv /tmp/geoserver-${GS_VERSION}/geoserver/data ~/geoserver_data
rm -r  /tmp/geoserver-${GS_VERSION} && cp controlflow.properties ~/geoserver_data
chmod -R a+rwx ~/geoserver_data
docker run -d -p 8580:8080 --name "geoserver" -v $HOME/geoserver_data:/opt/geoserver/data_dir kartoza/geoserver:${GS_VERSION}

```
Create an empty data directory to use to persist your data.

```shell
mkdir -p ~/geoserver_data
docker run -d -v $HOME/geoserver_data:/opt/geoserver/data_dir kartoza/geoserver
```

You need to ensure the ``geoserver_data`` directory has sufficient permissions
for the docker process to read / write it.

### Control flow properties
if you have installed the control flow module to manage request in geoserver you need to copy the file
controlflow.properties to the base of the data directory. You can fine tune the control flow file
with other parameters as defined in the [documentation](http://docs.geoserver.org/latest/en/user/extensions/controlflow/index.html)

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
