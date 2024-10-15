FROM bellsoft/liberica-openjdk-alpine:13 AS activemq-prod

LABEL maintainer="Alessio Fabiani <alessio.fabiani@geosolutionsgroup.com>"

ENV ACTIVEMQ_VERSION=5.17.1
ENV ACTIVEMQ=apache-activemq-$ACTIVEMQ_VERSION
ENV ACTIVEMQ_HOME=/opt/activemq/
ENV ACTIVEMQ_CONF=$ACTIVEMQ_HOME/conf/
ENV ACTIVEMQ_LIB=$ACTIVEMQ_HOME/lib/optional/


RUN apk add --update curl && \
    rm -rf /var/cache/apk/* && \
    mkdir -p /opt && \
    curl -s -S https://archive.apache.org/dist/activemq/$ACTIVEMQ_VERSION/$ACTIVEMQ-bin.tar.gz | tar -xvz -C /opt && \
    mv /opt/$ACTIVEMQ $ACTIVEMQ_HOME && \
    addgroup -S activemq && \
    adduser -S -H -G activemq -h $ACTIVEMQ_HOME activemq && \
    chown -R activemq:activemq $ACTIVEMQ_HOME && \
    chown -h activemq:activemq $ACTIVEMQ_HOME

ADD setup-jars.sh /setup-jars.sh
RUN chmod +x /*.sh;/setup-jars.sh

COPY activemq.xml $ACTIVEMQ_CONF/activemq.xml

# EXPOSE 1883 5672 8161 61613 61614 61616

USER activemq
WORKDIR $ACTIVEMQ_HOME

CMD ["/bin/sh", "-c", "bin/activemq console"]
