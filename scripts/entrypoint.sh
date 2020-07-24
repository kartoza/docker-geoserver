#!/bin/bash
set -e



/scripts/start.sh

export GEOSERVER_OPTS="-Djava.awt.headless=true -server -Xms${INITIAL_MEMORY} -Xmx${MAXIMUM_MEMORY} \
       -XX:PerfDataSamplingInterval=500 -Dorg.geotools.referencing.forceXY=true \
       -XX:SoftRefLRUPolicyMSPerMB=36000  -XX:NewRatio=2 \
       -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=20 -XX:ConcGCThreads=5 \
       -XX:InitiatingHeapOccupancyPercent=70 -XX:+CMSClassUnloadingEnabled -Dfile.encoding=UTF8 \
       -Duser.timezone=GMT -Djavax.servlet.request.encoding=UTF-8 -Djavax.servlet.response.encoding=UTF-8 \
       -DGEOSERVER_DATA_DIR=${GEOSERVER_DATA_DIR} -Dorg.geotools.shapefile.datetime=true \
       -Ds3.properties.location=${GEOSERVER_DATA_DIR}/s3.properties \
       -Dsun.java2d.renderer.useThreadLocal=false -Dsun.java2d.renderer.pixelsize=8192 -server -XX:NewSize=300m \
       -Dlog4j.configuration=${CATALINA_HOME}/log4j.properties \
       --patch-module java.desktop=${CATALINA_HOME}/marlin-0.9.4.2-Unsafe-OpenJDK9.jar  \
       -Dsun.java2d.renderer=org.marlin.pisces.PiscesRenderingEngine \
       -Dgeoserver.xframe.shouldSetPolicy=${XFRAME_OPTIONS} --add-modules java.se \
       --add-exports java.base/jdk.internal.ref=ALL-UNNAMED --add-opens java.base/java.lang=ALL-UNNAMED \
       --add-opens java.base/java.nio=ALL-UNNAMED --add-opens java.base/sun.nio.ch=ALL-UNNAMED \
       --add-opens java.management/sun.management=ALL-UNNAMED \
       --add-opens jdk.management/com.sun.management.internal=ALL-UNNAMED "


## Preparare the JVM command line arguments
export JAVA_OPTS="${JAVA_OPTS} ${GEOSERVER_OPTS}"



exec /usr/local/tomcat/bin/catalina.sh run
