#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
FROM tomcat:9.0.5-jre8
MAINTAINER joseph.b.murphy1@gmail.com
#credit: thinkWhere<info@thinkwhere.com>
#Credit: Tim Sutton<tim@linfiniti.com>
# Debian 9 (Stretch) /TOMCAT 9.0.1/Oracle JDK 8/GEOSERVER 2.12.1

RUN  export DEBIAN_FRONTEND=noninteractive
ENV  DEBIAN_FRONTEND noninteractive
RUN  dpkg-divert --local --rename --add /sbin/initctl
COPY ./openjdk-8-jre_8u162-b12-1_deb9u1_amd64.deb \
     ./libtcnative-1_1.2.14-1_amd64.deb \
     ./libjpeg-turbo-official_1.5.2_amd64.deb /tmp/
RUN apt-get -y update && apt-get -y upgrade
RUN apt-get install -y libgtk-3-0 libatk-wrapper-java-jni libpulse0
RUN dpkg -i /tmp/openjdk-8-jre_8u162-b12-1_deb9u1_amd64.deb
RUN echo "Yes, do as I say!" | apt-get remove --force-yes sed
RUN echo "Yes, do as I say!" | apt-get remove --force-yes login
RUN apt-get remove -y libsndfile1 libtiff5
RUN dpkg -i /tmp/libtcnative-1_1.2.14-1_amd64.deb
RUN dpkg --remove --force-depends libjpeg62-turbo libcups2 libwayland-client0 libwayland-cursor0 \
         libwayland-server0 libwayland-egl1 libvorbis0a libvorbisenc2 \
         libglib2.0-0 libcairo2 libcairo-gobject2 libpangocairo-1.0-0 \
         librsvg2-2 librsvg2-common uidmap libudev1 libsystemd0 libxml2 \
         libk5crypto3 libkrb5support0 libcroco3
RUN dpkg -i /tmp/libjpeg-turbo-official_1.5.2_amd64.deb



#-------------Application Specific Stuff ----------------------------------------------------
ENV GS_VERSION 2.12.1
ENV GEOSERVER_DATA_DIR /opt/geoserver/data_dir

RUN mkdir -p $GEOSERVER_DATA_DIR

# Unset Java related ENVs since they may change with Oracle JDK
ENV JAVA_VERSION=
ENV JAVA_DEBIAN_VERSION=

# Set JAVA_HOME to /usr/lib/jvm/default-java and link it to OpenJDK installation
RUN ln -s /usr/lib/jvm/java-8-openjdk-amd64 /usr/lib/jvm/default-java
ENV JAVA_HOME /usr/lib/jvm/default-java

ADD resources /tmp/resources

# Optionally add JAI and ImageIO for improved performance.

WORKDIR /tmp
ARG JAI_IMAGEIO=true
RUN if [ "$JAI_IMAGEIO" = true ]; then \
    wget http://download.java.net/media/jai/builds/release/1_1_3/jai-1_1_3-lib-linux-amd64.tar.gz && \
    wget http://download.java.net/media/jai-imageio/builds/release/1.1/jai_imageio-1_1-lib-linux-amd64.tar.gz && \
    gunzip -c jai-1_1_3-lib-linux-amd64.tar.gz | tar xf - && \
    gunzip -c jai_imageio-1_1-lib-linux-amd64.tar.gz | tar xf - && \
    mv /tmp/jai-1_1_3/lib/*.jar $JAVA_HOME/jre/lib/ext/ && \
    mv /tmp/jai-1_1_3/lib/*.so $JAVA_HOME/jre/lib/amd64/ && \
    mv /tmp/jai_imageio-1_1/lib/*.jar $JAVA_HOME/jre/lib/ext/ && \
    mv /tmp/jai_imageio-1_1/lib/*.so $JAVA_HOME/jre/lib/amd64/ && \
    rm /tmp/jai-1_1_3-lib-linux-amd64.tar.gz && \
    rm -r /tmp/jai-1_1_3 && \
    rm /tmp/jai_imageio-1_1-lib-linux-amd64.tar.gz && \
    rm -r /tmp/jai_imageio-1_1; \
    fi

# Add GDAL native libraries if the build-arg GDAL_NATIVE = true
ARG GDAL_NATIVE=true
# EWC and JP2ECW are subjected to licence restrictions

ENV GDAL_DATA $CATALINA_HOME/gdal-data
ENV LD_LIBRARY_PATH $JAVA_HOME/jre/lib/amd64/gdal:/usr/local/lib:/usr/lib/x86_64-linux-gnu:/opt/libjpeg-turbo/lib64
RUN if [ "$GDAL_NATIVE" = true ]; then \
    wget http://demo.geo-solutions.it/share/github/imageio-ext/releases/1.1.X/1.1.12/native/gdal/gdal-data.zip && \
    wget http://demo.geo-solutions.it/share/github/imageio-ext/releases/1.1.X/1.1.12/native/gdal/linux/gdal192-Ubuntu12-gcc4.6.3-x86_64.tar.gz && \
    unzip gdal-data.zip -d $CATALINA_HOME && \
    mkdir $JAVA_HOME/jre/lib/amd64/gdal && \
    tar -xvf gdal192-Ubuntu12-gcc4.6.3-x86_64.tar.gz -C $JAVA_HOME/jre/lib/amd64/gdal; \
    fi

WORKDIR $CATALINA_HOME

# Fetch the geoserver war file if it
# is not available locally in the resources dir and
RUN if [ ! -f /tmp/resources/geoserver.zip ]; then \
    wget -c https://downloads.sourceforge.net/project/geoserver/GeoServer/2.12.1/geoserver-2.12.1-war.zip \
      -O /tmp/resources/geoserver.zip; \
    fi; \
    unzip /tmp/resources/geoserver.zip -d /tmp/geoserver \
    && unzip /tmp/geoserver/geoserver.war -d $CATALINA_HOME/webapps/geoserver \
    && rm -rf $CATALINA_HOME/webapps/geoserver/data \
    && rm -rf /tmp/geoserver

# Install any plugin zip files in resources/plugins
RUN if ls /tmp/resources/plugins/*.zip > /dev/null 2>&1; then \
      for p in /tmp/resources/plugins/*.zip; do \
        unzip $p -d /tmp/gs_plugin \
        && mv /tmp/gs_plugin/*.jar $CATALINA_HOME/webapps/geoserver/WEB-INF/lib/ \
        && rm -rf /tmp/gs_plugin; \
      done; \
    fi;

COPY ./sqljdbc4-4.0.jar $CATALINA_HOME/webapps/geoserver/WEB-INF/lib/

# Overlay files and directories in resources/overlays if they exist
RUN if ls /tmp/resources/overlays/* > /dev/null 2>&1; then \
      cp -rf /tmp/resources/overlays/* /; \
    fi;

# install Font files in resources/fonts if they exist
RUN if ls /tmp/resources/fonts/*.ttf > /dev/null 2>&1; then \
      cp -rf /tmp/resources/fonts/*.ttf /usr/share/fonts/truetype/; \
	fi;

# Optionally disable GeoWebCache
# (Note that this forcibly removes all gwc files. This may cause errors with extensions that depend on gwc files
#   including:  Inspire; Control-Flow; )
ARG DISABLE_GWC=false
RUN if [ "$DISABLE_GWC" = true ]; then \
      rm $CATALINA_HOME/webapps/geoserver/WEB-INF/lib/*gwc*; \
    fi;

# Optionally remove Tomcat manager, docs, and examples
ARG TOMCAT_EXTRAS=false
RUN if [ "$TOMCAT_EXTRAS" = false ]; then \
    rm -rf $CATALINA_HOME/webapps/ROOT && \
    rm -rf $CATALINA_HOME/webapps/docs && \
    rm -rf $CATALINA_HOME/webapps/examples && \
    rm -rf $CATALINA_HOME/webapps/host-manager && \
    rm -rf $CATALINA_HOME/webapps/manager; \
  fi;

# Add unlimited crypto support
ENV JRE_HOME $JAVA_HOME/jre
COPY ./UnlimitedJCEPolicyJDK8/*.jar $JRE_HOME/lib/security/

#RUN export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib:/usr/lib/x86_64-linux-gnu:/opt/libjpeg-turbo/lib64

#webxml update for environment
RUN rm /usr/local/tomcat/webapps/geoserver/WEB-INF/web.xml
COPY ./web.xml /usr/local/tomcat/webapps/geoserver/WEB-INF/

# Delete resources after installation
RUN rm -rf /tmp/resources \
    rm /tmp/*.zip \
    rm /tmp/*.deb \
    rm /tmp/*.tar.gz \
    rm /usr/lib/mime/packages/util-linux


#Make Java DATA_DIR servlet path
RUN mkdir /var/lib/geoserver_data
#Set the GEOSERVER_DATA_DIR
RUN export GEOSERVER_DATA_DIR=/var/lib/geoserver_data
RUN printf '\nCATALINA_OPTS="-DGEOSERVER_DATA_DIR=/var/lib/geoserver_data"' >> $CATALINA_HOME/bin/setclasspath.sh

#ENV GEOSERVER_HOME /opt/geoserver

#Vulnerablities remediation section
RUN rm /usr/local/tomcat/webapps/geoserver/WEB-INF/lib/commons-fileupload-1.2.1.jar
RUN rm /var/lib/dpkg/info/util-linux.*

#change Container from Root User to ONEUSER
RUN groupadd -r oneuser -g 999 && \
    useradd -d /home/oneuser -u 999 -m -s /bin/bash -g oneuser oneuser
RUN chown -R oneuser:oneuser /usr/local/tomcat
#clean up prior to switching to oneuser
RUN dpkg --remove --force-depends multiarch-support passwd apt libapt-pkg5.0 libgssapi-krb5-2 libkrb5-3 \
         libidn11 openssl libssl1.1 wget unzip 	libgraphite2-3
RUN rm -rf /var/lib/apt/lists/*
USER oneuser

HEALTHCHECK --start-period=5m --interval=20m --timeout=5s CMD curl -f "http://localhost:8080/geoserver/ows?service=wfs&version=1.1.0&request=GetCapabilities" || exit 1

#ENTRYPOINT "/opt/geoserver/bin/startup.sh"
#CMD "/opt/geoserver/bin/startup.sh"
EXPOSE 8080