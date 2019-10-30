#!/bin/bash
set -e


if [[ -f ${GEOSERVER_DATA_DIR}/controlflow.properties  ]]; then \
    rm ${GEOSERVER_DATA_DIR}/controlflow.properties
fi;


cat > ${GEOSERVER_DATA_DIR}/controlflow.properties <<EOF
timeout=${REQUEST_TIMEOUT}
ows.global=${PARARELL_REQUEST}
ows.wms.getmap=${GETMAP}
ows.wfs.getfeature.application/msexcel=${REQUEST_EXCEL}
user=${SINGLE_USER}
ows.gwc=${GWC_REQUEST}
user.ows.wps.execute=${WPS_REQUEST}
EOF


export GEOSERVER_OPTS="-Djava.awt.headless=true -server -Xms${INITIAL_MEMORY} -Xmx${MAXIMUM_MEMORY} -Xrs -XX:PerfDataSamplingInterval=500 \
       -Dorg.geotools.referencing.forceXY=true -XX:SoftRefLRUPolicyMSPerMB=36000 -XX:+UseParallelGC -XX:NewRatio=2 \
       -XX:+CMSClassUnloadingEnabled -Dfile.encoding=UTF8 -Duser.timezone=GMT -Djavax.servlet.request.encoding=UTF-8 \
       -Djavax.servlet.response.encoding=UTF-8 -Duser.timezone=GMT -Dorg.geotools.shapefile.datetime=true \
       -Dorg.geotools.shapefile.datetime=true -Ds3.properties.location=${GEOSERVER_DATA_DIR}/s3.properties \
       -Xbootclasspath/a:${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/marlin.jar \
       -Xbootclasspath/p:${CATALINA_HOME}/webapps/geoserver/WEB-INF/lib/marlin-sun-java2d.jar \
       -Dsun.java2d.renderer=org.marlin.pisces.PiscesRenderingEngine -Dgeoserver.xframe.policy=${XFRAME_OPTIONS}"

## Preparare the JVM command line arguments
export JAVA_OPTS="${JAVA_OPTS} ${GEOSERVER_OPTS}"

/scripts/update_passwords.sh
exec /usr/local/tomcat/bin/catalina.sh run
