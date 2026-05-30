# Table of Contents

- [Developer Guidelines](#developer-guidelines)
  * [Building the image](#building-the-image)
    + [Local build using repository checkout](#local-build-using-repository-checkout)
    + [Building with a specific version of Tomcat](#building-with-a-specific-version-of-tomcat)
  * [Building on Windows](#building-on-windows)
  * [Upgrading GeoServer Versions](#upgrading-geoserver-versions)
    + [Run upgrade helper script](#run-upgrade-helper-script)
  * [Security Vulnerabilities](#security-vulnerabilities)

# Developer Guidelines 

This outlines the steps for building the docker image locally
allowing user customisations.

## Building the image

### Local build using repository checkout

To build yourself with a local checkout using the docker-compose-build.yml:

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

To build using a specific tagged release of the tomcat image set the
`IMAGE_VERSION` build arg:
See the [dockerhub tomcat](https://hub.docker.com/_/tomcat/)
for available tags.

```
VERSION=2.28.4
IMAGE_VERSION=9.0.99-jdk11-temurin-noble
docker build --build-arg IMAGE_VERSION=${IMAGE_VERSION} --build-arg GS_VERSION=${VERSION} -t kartoza/geoserver:${VERSION} .
```

For some recent builds, it is necessary to set the JAVA_PATH as well (e.g. Apache Tomcat/9.0.36)

```
docker build --build-arg IMAGE_VERSION=9.0.99-jdk11-temurin-noble --build-arg JAVA_HOME=/usr/local/openjdk-11/bin/java --build-arg GS_VERSION=2.28.4 -t kartoza/geoserver:2.28.4 .
```

**Note:** Please check the [GeoServer documentation](https://docs.geoserver.org/stable/en/user/production/index.html)
to see which Tomcat versions are supported.

## Building on Windows

These instructions detail the recommended process for reliably building this on Windows.

Prerequisites - You will need to have this software preinstalled on the system being used to build the Geoserver image:

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

GeoServer releases and bug fixes are done frequently. We provide a helper script
`upgrade_geoserver_version.sh` which can be run to update the
respective files which mention the GeoServer version. To upgrade to
a new version involves:

1. Run the upgrade script that updates some env variables.
2. Update the [github workflows](https://github.com/kartoza/docker-geoserver/tree/develop/.github/workflows) files to.
   match the specific versions.

### Run upgrade helper script

```bash
/bin/bash upgrade_geoserver_version.sh ${GS_VERSION} ${GS_NEW_VERSION}
```

**Note:** The script will also push these changes to the current repo, and it is up to the individual running the script
to push the changes to his specific branch of choice and then complete the pull request

## Security Vulnerabilities

The published image uses [Trivy](https://trivy.dev/latest/) to scan vulnerabilities. These vulnerabilities
are listed in the [security section](https://github.com/kartoza/docker-geoserver/security/code-scanning).
You can also use other tools to scan the image for vulnerabilities i.e. `docker scan`.
The images also inherit vulnerabilities from the base images i.e. [tomcat:9.0.99-jdk11-temurin-noble](https://hub.docker.com/_/tomcat/tags?name=9.0.99-jdk11-temurin-noble).
So when reporting please vulnerabilities please try to distinguish them from the following:

-   Base image vulnerabilities - These should be reported in the upstream tomcat repository
    and if any fix is applied, we will have to build a new image using a newer image tag.
-   Packages installed with these images i.e. gosu. These should be reported as an
    issue in this repository and should be tagged with the `security` label.
-   Vulnerabilities directly related to libs installed with the GeoServer application, these
    should be reported upstream following the guidelines from [upstream geoserver](https://github.com/geoserver/geoserver/blob/main/SECURITY.md)

Other platforms where users can ask questions and get assistance are listed below:

-   [Stack Exchange](https://stackexchange.com/)
-   [GeoServer Mailing lists](https://sourceforge.net/projects/geoserver/lists/geoserver-users)
-   [GeoServer Commercial Support](https://geoserver.org/support/)

