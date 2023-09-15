# Instructions

Builds an image to use with GeoNode.

## Building locally

```bash
IMAGE_VERSION=2.23.0
docker build --build-arg HTTP_PROXY=${IMAGE_VERSION} -t kartoza/geoserver:geonode-2.23.0 
```

The build uses an upstream `kartoza/geoserver:$VERSION` image.
All the env variables available in the upstream image can be used here in combination 
with some custom GeoNode variables.

## GeoNode Environment Variables

```bash
PRINT_BASE_URL=http://localhost:8080/geoserver/pdf
SAMPLE_DATA=TRUE
RUN_AS_ROOT=TRUE
NGINX_BASE_URL=http://geonode:80
```

**NOTE:** Please refer to the GeoNode documentation to check what other
environment variables are needed.