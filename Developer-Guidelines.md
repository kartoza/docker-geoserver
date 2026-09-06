# Table of Contents

- [Developer Guidelines](#developer-guidelines)
  * [Building the image](#building-the-image)
    + [Local build using compose configuration](#local-build-using-compose-configuration)
    + [Building with a specific version of Tomcat](#building-with-a-specific-version-of-tomcat)
  * [Building on Windows](#building-on-windows)
  * [Upgrading GeoServer Versions](#upgrading-geoserver-versions)
    + [Run upgrade helper script](#run-upgrade-helper-script)
  * [Security Vulnerabilities](#security-vulnerabilities)
  * [Github Workflows](#github-workflows)

# Developer Guidelines 

This outlines the different methods for building the docker 
image locally, allowing finer customizations using
build arguments.

## Building the image

### Local build using compose configuration

To build using `docker-compose-build.yml`:

1. Clone the GitHub repository:

    ```shell
    git clone https://github.com/kartoza/docker-geoserver
    ```

2. Edit the [build arguments](https://github.com/kartoza/docker-geoserver/blob/master/compose/.env) in the `.env` file:

3. Build the container and spin up the services
    ```shell
    cd docker-geoserver
    docker-compose -f docker-compose-build.yml up -d geoserver-prod --build
    ```

### Building with a specific version of Tomcat

To build using a specific tagged release of the tomcat image,
set the `IMAGE_VERSION` build arg: See the [dockerhub tomcat](https://hub.docker.com/_/tomcat/) 
for available tags.

```
VERSION=3.0.1
IMAGE_VERSION=11.0.23-jdk21-temurin-noble
docker build --build-arg IMAGE_VERSION=${IMAGE_VERSION} --build-arg GS_VERSION=${VERSION} -t kartoza/geoserver:${VERSION} .
```

For some recent builds, it is necessary to set the JAVA_PATH as well.

```
docker build --build-arg IMAGE_VERSION=11.0.23-jdk21-temurin-noble --build-arg JAVA_HOME=/usr/local/openjdk-11/bin/java --build-arg GS_VERSION=3.0.1 -t kartoza/geoserver:3.0.1 .
```

**Note:** Please check the [GeoServer documentation](https://docs.geoserver.org/stable/en/user/production/index.html)
to see which Tomcat versions are supported.

## Building on Windows

These instructions detail the recommended process for reliably building this on Windows.

Prerequisites – You will need to have this software preinstalled on the system being used to build the Geoserver image:

-   Docker Desktop with WSL2
-   [Java JDK](https://jdk.java.net/)
-   [Conda](https://conda.io/)
-   GDAL (Install with Conda)

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
cd compose
docker-compose -f docker-compose-build.yml build --force-rm --no-cache
docker-compose -f docker-compose-build.yml up -d
```

## Upgrading GeoServer Versions

GeoServer releases and bug fixes are done frequently. 
We provide a helper script `upgrade_geoserver_version.sh` 
which can be run to update the respective files which 
specify the GeoServer version. 

Upgrading to a new version involves:

1. Running the upgrade script to update Geoserver versions.

### Run upgrade helper script

```bash
/bin/bash upgrade_geoserver_version.sh ${GS_VERSION} ${GS_NEW_VERSION} ${PUSH_CHANGES}
```


## Security Vulnerabilities

The published image uses [Trivy](https://trivy.dev/latest/) to scan vulnerabilities. These vulnerabilities
are listed in the [security section](https://github.com/kartoza/docker-geoserver/security/code-scanning).
You can also use other tools to scan the image for vulnerabilities i.e. `docker scan`.
The images also inherit vulnerabilities from the base images 
We use the latest version of tomcat in the series  i.e. `11.0.x`.


-   Base image vulnerabilities – These should be reported in the upstream tomcat repository.
    and if any fix is applied, we will have to build a new image using a newer image tag.
-   Vulnerabilities directly related to libs installed with the GeoServer application, these
    should be reported upstream following the guidelines from [upstream geoserver](https://github.com/geoserver/geoserver/blob/main/SECURITY.md)

Other platforms where users can ask questions and get assistance are listed below:

-   [Stack Exchange](https://stackexchange.com/)
-   [GeoServer User Forum](https://discourse.osgeo.org/c/geoserver/user/51)
-   [GeoServer Commercial Support](https://geoserver.org/support/)

## Github Workflows

The GitHub workflows are used to build and publish the docker images.
They also make sure that at each invocation they will
build the Geoserver image with the latest versions of

1. Tomcat base image i.e. `tomcat:11.0.23-jdk21-temurin-noble`
2. GeoServer (the latest stable version).
3. GeoServer latest community and stable versions.

We also have a weekly workflow that builds and publishes
GeoServer images to ensure that we have the latest
base images:

```bash
Published GeoServer: 3.0.1
Latest GeoServer:    3.0.1
Published Tomcat:    11.0.25-jdk21-temurin-noble
Latest Tomcat:       11.0.25-jdk21-temurin-noble
Latest Tomcat Digest:       tomcat@sha256:133546e3740f0e17d2307d9b324de082062b009226a602111a422016f1e84173
Published Tomcat Digest:    tomcat@sha256:8861f17dd3960026009a77a9c7530b709f9bc6d4cf950238cd956b2b6a952611
Tomcat version changed
```

The following table summarizes the changes that will trigger a new image build:
| What changed | `latest` | `x.y.z` | `x.y.z--vDATE` | GitHub release |
|---|:---:|:---:|:---:|:---:|
| Normal Dockerfile/scripts/code change | ✅ | ❌ | ✅ | ✅ |
| Tomcat digest only | ✅ | ✅ | ❌ | ❌ |
| Tomcat version | ✅ | ✅ | ❌ | ❌ |
| New GeoServer version | ✅ | ✅ | ✅ | ✅ |
| Missing `x.y.z` tag | ✅ | ✅ | ✅ | ✅ |
| Explicit `geoserverPatchMajorVersionBugs=yes` | ✅ | ✅ | ✅ | ✅ |

