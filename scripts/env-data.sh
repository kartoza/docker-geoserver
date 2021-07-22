#!/bin/bash

if [ -z ${ENABLE_JSONP} ]; then
    ENABLE_JSONP=true
fi

if [ -z ${MAX_FILTER_RULES} ]; then
  MAX_FILTER_RULES=20
fi

if [ -z ${OPTIMIZE_LINE_WIDTH} ]; then
  OPTIMIZE_LINE_WIDTH=false
fi

if [ -z ${SSL} ]; then
  SSL=false
fi

if [ -z ${TOMCAT_EXTRAS} ]; then
  TOMCAT_EXTRAS=true
fi

if [ -z ${HTTP_PORT} ]; then
  HTTP_PORT=8080
fi

if [ -z ${HTTP_PROXY_NAME} ]; then
  HTTP_PROXY_NAME=
fi

if [ -z ${HTTP_PROXY_PORT} ]; then
  HTTP_PROXY_PORT=
fi

if [ -z ${HTTP_REDIRECT_PORT} ]; then
  HTTP_REDIRECT_PORT=
fi

if [ -z ${HTTP_CONNECTION_TIMEOUT} ]; then
  HTTP_CONNECTION_TIMEOUT=20000
fi

if [ -z ${HTTPS_PORT} ]; then
  HTTPS_PORT=8443
fi

if [ -z ${HTTPS_MAX_THREADS} ]; then
  HTTPS_MAX_THREADS=150
fi

if [ -z ${HTTPS_CLIENT_AUTH} ]; then
  HTTPS_CLIENT_AUTH=
fi

if [ -z ${HTTPS_PROXY_NAME} ]; then
  HTTPS_PROXY_NAME=
fi

if [ -z ${HTTPS_PROXY_PORT} ]; then
  HTTPS_PROXY_PORT=
fi

if [ -z ${JKS_FILE} ]; then
  JKS_FILE=letsencrypt.jks
fi

if [ -z ${JKS_KEY_PASSWORD} ]; then
  JKS_KEY_PASSWORD='geoserver'
fi

if [ -z ${KEY_ALIAS} ]; then
  KEY_ALIAS=letsencrypt
fi

if [ -z ${JKS_STORE_PASSWORD} ]; then
    JKS_STORE_PASSWORD='geoserver'
fi

if [ -z ${P12_FILE} ]; then
    P12_FILE=letsencrypt.p12
fi

if [ -z ${PKCS12_PASSWORD} ]; then
    PKCS12_PASSWORD='geoserver'
fi


if [ -z ${GEOSERVER_CSRF_DISABLED} ]; then
    GEOSERVER_CSRF_DISABLED=true
fi

if [ -z ${ENCODING} ]; then
    ENCODING='UTF8'
fi

if [ -z ${TIMEZONE} ]; then
    TIMEZONE='GMT'
fi

if [ -z ${CHARACTER_ENCODING} ]; then
    CHARACTER_ENCODING='UTF-8'
fi

if [ -z ${CLUSTERING} ]; then
    CLUSTERING=False
fi

if [ -z ${CLUSTER_DURABILITY} ]; then
    CLUSTER_DURABILITY=true
fi

if [ -z ${BROKER_URL} ]; then
    BROKER_URL=
fi

if [ -z ${READONLY} ]; then
    READONLY=disabled
fi

if [ -z ${RANDOMSTRING} ]; then
    RANDOMSTRING=23bd87cfa327d47e
fi

if [ -z ${INSTANCE_STRING} ]; then
    INSTANCE_STRING=ac3bcba2fa7d989678a01ef4facc4173010cd8b40d2e5f5a8d18d5f863ca976f
fi

if [ -z ${TOGGLE_MASTER} ]; then
    TOGGLE_MASTER=true
fi

if [ -z ${TOGGLE_SLAVE} ]; then
    TOGGLE_SLAVE=true
fi

if [ -z ${EMBEDDED_BROKER} ]; then
    EMBEDDED_BROKER=enabled
fi

if [ -z ${DB_BACKEND} ]; then
    DB_BACKEND=
fi

if [ -z ${LOGIN_STATUS} ]; then
    LOGIN_STATUS=on
fi

if [ -z ${WEB_INTERFACE} ]; then
    WEB_INTERFACE=false
fi

if [ -z ${RECREATE_DATADIR} ]; then
    RECREATE_DATADIR=false
fi

if [ -z ${INITIAL_MEMORY} ]; then
    INITIAL_MEMORY="2G"
fi

if [ -z ${MAXIMUM_MEMORY} ]; then
    MAXIMUM_MEMORY="4G"
fi

if [ -z ${XFRAME_OPTIONS} ]; then
    XFRAME_OPTIONS="true"
fi

if [ -z ${REQUEST_TIMEOUT} ]; then
    REQUEST_TIMEOUT=60
fi

if [ -z ${PARARELL_REQUEST} ]; then
    PARARELL_REQUEST=100
fi

if [ -z ${GETMAP} ]; then
    GETMAP=10
fi

if [ -z ${REQUEST_EXCEL} ]; then
    REQUEST_EXCEL=4
fi

if [ -z ${SINGLE_USER} ]; then
    SINGLE_USER=6
fi

if [ -z ${GWC_REQUEST} ]; then
    GWC_REQUEST=16
fi

if [ -z ${WPS_REQUEST} ]; then
    WPS_REQUEST='1000/d;30s'
fi

if [ -z ${S3_SERVER_URL} ]; then
    S3_SERVER_URL=''
fi

if [ -z ${S3_USERNAME} ]; then
    S3_USERNAME=''
fi

if [ -z ${S3_PASSWORD} ]; then
    S3_PASSWORD=''
fi

if [ -z ${SAMPLE_DATA} ]; then
    SAMPLE_DATA='FALSE'
fi

if [ -z ${GEOSERVER_FILEBROWSER_HIDEFS} ]; then
    GEOSERVER_FILEBROWSER_HIDEFS=false
fi

if [ -z ${TOMCAT_PASSWORD} ]; then
    TOMCAT_PASSWORD='tomcat'
fi

if [ -z ${TOMCAT_USER} ]; then
    TOMCAT_USER='tomcat'
fi


if [ -z ${GEOSERVER_ADMIN_USER} ]; then
    GEOSERVER_ADMIN_USER='admin'
fi



if [ -z ${CSRF_WHITELIST} ]; then
    CSRF_WHITELIST=
fi

if [ -z ${INITIAL_HEAT_OCCUPANCY_PERCENT} ]; then
    INITIAL_HEAT_OCCUPANCY_PERCENT=45
fi

if [ -z ${CSRF_WHITELIST} ]; then
    CSRF_WHITELIST=
fi

if [ -z ${POSTGRES_JNDI} ]; then
    POSTGRES_JNDI=FALSE
fi
