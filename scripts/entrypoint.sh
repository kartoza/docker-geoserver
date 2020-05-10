#!/bin/bash
set -e



/scripts/start.sh

export GEOSERVER_OPTS="-Djava.awt.headless=true -server -Xms${INITIAL_MEMORY} -Xmx${MAXIMUM_MEMORY} \
       -Xrs -XX:PerfDataSamplingInterval=500 \
       -Dorg.geotools.referencing.forceXY=true -XX:SoftRefLRUPolicyMSPerMB=36000 -XX:+UseParallelGC -XX:NewRatio=2 \
       -XX:+CMSClassUnloadingEnabled -Dfile.encoding=UTF8 -Duser.timezone=GMT -Djavax.servlet.request.encoding=UTF-8 \
       -Djavax.servlet.response.encoding=UTF-8  -Dorg.geotools.shapefile.datetime=true \
       -Ds3.properties.location=${GEOSERVER_DATA_DIR}/s3.properties \
       -Dlog4j.configuration=${CATALINA_HOME}/log4j.properties \
       -Xbootclasspath/a:${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/marlin.jar \
       -Xbootclasspath/p:${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/marlin-sun-java2d.jar \
       -Dsun.java2d.renderer=org.marlin.pisces.PiscesRenderingEngine -Dgeoserver.xframe.shouldSetPolicy=${XFRAME_OPTIONS}"

## Preparare the JVM command line arguments
export JAVA_OPTS="${JAVA_OPTS} ${GEOSERVER_OPTS}"

exec /usr/local/tomcat/bin/catalina.sh run