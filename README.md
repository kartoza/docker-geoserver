# Table of Contents

- [Kartoza docker-geoserver](#kartoza-docker-geoserver)
  * [Getting the image](#getting-the-image)
    + [Pulling from Central Registry(Dockerhub)](#pulling-from-central-registry-dockerhub-)
  * [Running the Image](#running-the-image)
    + [Run (automated using docker-compose)](#run--automated-using-docker-compose-)
  * [Advanced Documentation](#advanced-documentation)
  * [Contributing to the image](#contributing-to-the-image)
  * [Support](#support)
  * [Credits](#credits)

# Kartoza docker-geoserver

## Overview

-   A simple docker container that runs GeoServer influenced by this [docker recipe](https://github.com/eliotjordan/docker-geoserver/blob/master/Dockerfile).
-   The image has environment variables that allow users to configure GeoServer based on [running-in-production](https://docs.geoserver.org/latest/en/user/production/index.html)
-   Incorporates  PostgreSQL database backend. Currently backed
    to use [kartoza/postgis](https://github.com/kartoza/docker-postgis/) as a database backend. You can use any other PostgreSQL image
    but adjust the environment variables accordingly.

## Getting the image

To get the image onto your system:

-   Pulling from Central Registry (Dockerhub)
-   Building locally - Consult the [Developer Guidelines](https://github.com/kartoza/docker-geoserver/blob/develop/Developer-Guidelines.md)


### Pulling from Central Registry(Dockerhub)

The recommended approach (though it requires more bandwidth for the initial download) is to pull the trusted Docker image as follows:

```shell
VERSION=3.0.1
docker pull kartoza/geoserver:$VERSION
```

**Note** It is recommended to use tagged versions i.e. 
`kartoza/geoserver:$VERSION` for stability.


## Running the Image

### Run (automated using docker-compose)

We provide a sample `docker-compose.yml` file that illustrates
how you can establish a GeoServer + PostGIS.

Start the services using:

1) Navigate to the directory with compose yaml files.
    ```bash
    cd compose
    ```
2) Update `.env` to suit your need and start the services.

    ```shell
    docker-compose up -d
    ```

**Note** The default login credentials are stored in the `.env` file and should be updated to something more secure.. 

Once all the services start, test by visiting the GeoServer landing
page in your browser: [http://localhost:8600/geoserver](http://localhost:8600/geoserver).

### using command line

For a minimum example use the following:

```bash
GS_VERSION=3.0.1
docker run -d -p 8600:8080 --name geoserver -e GEOSERVER_ADMIN_PASSWORD=myawesomegeoserver -e GEOSERVER_ADMIN_USER=admin kartoza/geoserver:${GS_VERSION}
```
Navigate to the URL: http://localhost:8600/geoserver

## Advanced Documentation

This README focuses on simplicity. 
Additional documentation covering advanced configuration and examples can be found here:

1) [Advanced-Configuration](https://github.com/kartoza/docker-geoserver/blob/develop/Advanced-Configuration.md)
2) [Developer-Guidelines](https://github.com/kartoza/docker-geoserver/blob/develop/Developer-Guidelines.md) 

## Contributing to the image

We encourage community contributions. Kindly submit pull requests against the develop 
branch so they can be reviewed and tested before being merged into master. All existing
unit tests must pass for any changes, and new features or modifications should include 
accompanying unit tests where applicable.

## Support

When reporting issues especially those related to installed extensions (community or stable), please first consult the 
[GeoServer Issue page](https://osgeo-org.atlassian.net/jira/software/c/projects/GEOS/issues)￼ to check whether the issue has already been reported upstream. We rely on the GeoServer community
to address such upstream issues. For urgent upstream problems, consider obtaining paid support from the developers at 
[GeoServer](https://geoserver.org/).
 
* This repository focuses on the orchestration and packaging of GeoServer. 
* Issues specifically related to running the Docker image or its configuration should be reported here.
* Before opening an issue, please verify whether the problem originates from GeoServer itself or from this repository
by checking upstream reports.


## Credits

-   Tim Sutton (tim@kartoza.com)
-   Shane St Clair (shane@axiomdatascience.com)
-   Alex Leith (alexgleith@gmail.com)
-   Admire Nyakudya (addloe@gmail.com)
-   Gavin Fleming (gavin@kartoza.com)
