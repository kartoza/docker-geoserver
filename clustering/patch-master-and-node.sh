docker cp patched_jars/gs-jms-commons-2.21-SNAPSHOT.jar clustering-master-1:/usr/local/tomcat/webapps/geoserver/WEB-INF/lib/gs-jms-commons-2.21-SNAPSHOT.jar
docker cp patched_jars/gs-jms-commons-2.21-SNAPSHOT.jar clustering-node-1:/usr/local/tomcat/webapps/geoserver/WEB-INF/lib/gs-jms-commons-2.21-SNAPSHOT.jar

docker cp patched_jars/gs-jms-geoserver-2.21-SNAPSHOT.jar clustering-master-1:/usr/local/tomcat/webapps/geoserver/WEB-INF/lib/gs-jms-geoserver-2.21-SNAPSHOT.jar
docker cp patched_jars/gs-jms-geoserver-2.21-SNAPSHOT.jar clustering-node-1:/usr/local/tomcat/webapps/geoserver/WEB-INF/lib/gs-jms-geoserver-2.21-SNAPSHOT.jar

docker-compose stop master node
docker-compose restart master node
