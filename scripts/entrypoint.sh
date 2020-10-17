#!/bin/bash
set -e

/scripts/start.sh

CLUSTER_CONFIG_DIR="${GEOSERVER_DATA_DIR}/cluster/instance_$RANDOMSTRING"

export GEOSERVER_OPTS="-Djava.awt.headless=true -server -Xms${INITIAL_MEMORY} -Xmx${MAXIMUM_MEMORY} \
       -XX:PerfDataSamplingInterval=500 -Dorg.geotools.referencing.forceXY=true \
       -XX:SoftRefLRUPolicyMSPerMB=36000  -XX:NewRatio=2 \
       -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=20 -XX:ConcGCThreads=5 \
       -XX:InitiatingHeapOccupancyPercent=70 -XX:+CMSClassUnloadingEnabled \
       -Dfile.encoding=${ENCODING} \
       -Duser.timezone=${TIMEZONE} \
       -Djavax.servlet.request.encoding=${CHARACTER_ENCODING} \
       -Djavax.servlet.response.encoding=${CHARACTER_ENCODING} \
       -DCLUSTER_CONFIG_DIR=${CLUSTER_CONFIG_DIR} \
       -DGEOSERVER_DATA_DIR=${GEOSERVER_DATA_DIR} \
       -Dorg.geotools.shapefile.datetime=true \
       -Ds3.properties.location=${GEOSERVER_DATA_DIR}/s3.properties \
       -Dsun.java2d.renderer.useThreadLocal=false \
       -Dsun.java2d.renderer.pixelsize=8192 -server -XX:NewSize=300m \
       -Dlog4j.configuration=${CATALINA_HOME}/log4j.properties \
       --patch-module java.desktop=${CATALINA_HOME}/marlin-0.9.4.2-Unsafe-OpenJDK9.jar  \
       -Dsun.java2d.renderer=org.marlin.pisces.PiscesRenderingEngine \
       -Dgeoserver.login.autocomplete=${LOGIN_STATUS} \
       -DGEOSERVER_CONSOLE_DISABLED=${WEB_INTERFACE} \
       -Dgeoserver.xframe.shouldSetPolicy=${XFRAME_OPTIONS} "

## Preparare the JVM command line arguments
export JAVA_OPTS="${JAVA_OPTS} ${GEOSERVER_OPTS}"

exec /usr/local/tomcat/bin/catalina.sh run
