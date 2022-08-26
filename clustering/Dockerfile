FROM kartoza/geoserver:2.20.2

COPY ./patched_jars/gs-jms-commons-2.20-SNAPSHOT.jar /usr/local/tomcat/webapps/geoserver/WEB-INF/lib/gs-jms-commons-2.20-SNAPSHOT.jar
COPY ./patched_jars/gs-jms-geoserver-2.20-SNAPSHOT.jar /usr/local/tomcat/webapps/geoserver/WEB-INF/lib/gs-jms-geoserver-2.20-SNAPSHOT.jar

WORKDIR ${GEOSERVER_HOME}

CMD ["/bin/bash", "/scripts/entrypoint.sh"]
