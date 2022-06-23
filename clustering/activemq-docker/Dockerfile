FROM tomcat:9-jre8
RUN apt update -y; apt install -y net-tools
COPY activemqBroker-2.20-SNAPSHOT /usr/local/tomcat/webapps
CMD ["catalina.sh", "run"]