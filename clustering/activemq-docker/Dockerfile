FROM tomcat:9-jre11
RUN apt update -y; apt install -y net-tools

COPY activemqBroker-2.20-SNAPSHOT /usr/local/tomcat/webapps
COPY entrypoint.sh /usr/local/entrypoint.sh

CMD ["/bin/bash", "/usr/local/entrypoint.sh"]
