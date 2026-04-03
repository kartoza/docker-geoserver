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

-   A simple docker container that runs GeoServer influenced by this [docker recipe](https://github.com/eliotjordan/docker-geoserver/blob/master/Dockerfile).
-   The image has environment variables that allow users to configure GeoServer based on [running-in-production](https://docs.geoserver.org/latest/en/user/production/index.html)
-   The image uses [kartoza/postgis](https://github.com/kartoza/docker-postgis/) as a
    database backend. You can use any other PostgreSQL image
    but adjust the environment variables accordingly.

## Getting the image

To get the image onto your system:

-   Pulling from Dockerhub


### Pulling from Central Registry(Dockerhub)

The preferred way (but using the most bandwidth for the initial image) is to
get our docker-trusted build like this:

```shell
VERSION=2.28.3
docker pull kartoza/geoserver:$VERSION
```

**Note** It is recommended to use tagged versions i.e. `kartoza/geoserver:$VERSION`.


## Running the Image

### Run (automated using docker-compose)

We provide a sample `docker-compose.yml` file that illustrates
how you can establish a GeoServer + PostGIS.

Start the services using:

1) Navigate to the directory with compose yaml.
    ```bash
    cd compose
    ```
2) Start the services.

    ```shell
    docker-compose up -d
    ```

**Note** The username and password are specified in the `.env` file. It is recommended
to change them into something more secure. 

Once all the services start, test by visiting the GeoServer landing
page in your browser: [http://localhost:8600/geoserver](http://localhost:8600/geoserver).

## Advanced Documentation

The readme aims to be simplified as possible. Other readme's 
are provided with advanced configuration and examples:

1) [Advanced-Configuration](https://github.com/kartoza/docker-geoserver/blob/develop/Advanced-Configuration.md)
2) [Developer-Guidelines](https://github.com/kartoza/docker-geoserver/blob/develop/Developer-Guidelines.md) 

## Contributing to the image

We welcome users who want to contribute to enriching this service. We follow
the git principles and all pull requests should be against the develop branch so that
we can test them and when we are happy we push them to the master branch.

## Support

When reporting issues especially related to installed extensions (community and stable) please refer to the [GeoServer Issue page](https://osgeo-org.atlassian.net/jira/software/c/projects/GEOS/issues)
to see if there are no issues reported there. We rely on the GeoServer community to resolve upstream
issues. For urgent upstream problems, you will need to get paid support
from the developers in [GeoServer](https://geoserver.org/).


## Credits

-   Tim Sutton (tim@kartoza.com)
-   Shane St Clair (shane@axiomdatascience.com)
-   Alex Leith (alexgleith@gmail.com)
-   Admire Nyakudya (addloe@gmail.com)
-   Gavin Fleming (gavin@kartoza.com)
