# docker-geoserver

A simple docker container that runs Geoserver influenced by this docker
recipe: https://github.com/eliotjordan/docker-geoserver/blob/master/Dockerfile

**Note:** We recommend using ``apt-cacher-ng`` to speed up package fetching -
you should configure the host for it in the provided 71-apt-cacher-ng file.

## Getting the image

There are various ways to get the image onto your system:

The preferred way (but using most bandwidth for the initial image) is to
get our docker trusted build like this:


```
docker pull kartoza/geoserver
```

To build the image yourself without apt-cacher-ng (also consumes more bandwidth
since deb packages need to be refetched each time you build) do:

```
docker build -t kartoza/geoserver git://github.com/kartoza/docker-geoserver
```

To build with apt-cacher-ng (and minimised download requirements) do you need to
clone this repo locally first and modify the contents of 71-apt-cacher-ng to
match your cacher host. Then build using a local url instead of directly from
github.

```
git clone git://github.com/kartoza/docker-geoserver
```

Now edit ``71-apt-cacher-ng`` then do:

```
docker build -t kartoza/postgis .
```

## Run

You probably want to also have postgis running too. To create a running 
container do:

```
sudo docker run --name "postgis" -d -t kartoza/postgis
sudo docker run --name "geoserver"  --link postgis:postgis -p 8080:8080 -d -t kartoza/geoserver
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

```
mkdir -p ~/geoserver_data
docker run -d -v $HOME/geoserver_data:/opt/geoserver/data_dir kartoza/geserver
```

You need to ensure the ``geoserver_data`` directory has sufficinet permissions
for the docker process to read / write it.



## Credits

Tim Sutton (tim@kartoza.com)
May 2014
