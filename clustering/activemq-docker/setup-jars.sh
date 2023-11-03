#!/bin/sh

wget  -c --tries=2 https://repo1.maven.org/maven2/org/slf4j/slf4j-api/1.7.21/slf4j-api-1.7.21.jar \
-O "${ACTIVEMQ_LIB}"/slf4j-api-1.7.21.jar
wget  -c --tries=2 https://repo1.maven.org/maven2/org/postgresql/postgresql/42.4.0/postgresql-42.4.0.jar \
-O "${ACTIVEMQ_LIB}"/postgresql-42.4.0.jar
wget  -c --tries=2 https://repo1.maven.org/maven2/org/osgi/org.osgi.compendium/4.3.1/org.osgi.compendium-4.3.1.jar \
-O "${ACTIVEMQ_LIB}"/org.osgi.compendium-4.3.1.jar
wget  -c --tries=2 https://repo1.maven.org/maven2/org/apache/servicemix/bundles/org.apache.servicemix.bundles.commons-dbcp/1.4_3/org.apache.servicemix.bundles.commons-dbcp-1.4_3-sources.jar \
-O "${ACTIVEMQ_LIB}"/org.apache.servicemix.bundles.commons-dbcp-1.4_3-sources.jar
wget  -c --tries=2 https://repo1.maven.org/maven2/com/zaxxer/HikariCP/2.7.2/HikariCP-2.7.2.jar \
-O "${ACTIVEMQ_LIB}"/HikariCP-2.7.2.jar