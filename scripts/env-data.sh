#!/bin/bash

source /scripts/functions.sh

if [ -z "${ENABLE_JSONP}" ]; then
    ENABLE_JSONP=true
fi

if [ -z "${MAX_FILTER_RULES}" ]; then
  MAX_FILTER_RULES=20
fi

if [ -z "${OPTIMIZE_LINE_WIDTH}" ]; then
  OPTIMIZE_LINE_WIDTH=false
fi

if [ -z "${WMS_DIR_INTEGRATION}" ]; then
  WMS_DIR_INTEGRATION=true
fi

if [ -z "${REQUIRE_TILED_PARAMETER}" ]; then
  REQUIRE_TILED_PARAMETER=true
fi


if [ -z "${WMSC_ENABLED}" ]; then
  WMSC_ENABLED=true
fi

if [ -z "${DISKQUOTA_DISABLED}" ]; then
  DISKQUOTA_DISABLED=false
fi



if [ -z "${TMS_ENABLED}" ]; then
  TMS_ENABLED=true
fi


if [ -z "${SECURITY_ENABLED}" ]; then
  SECURITY_ENABLED=false
fi

if [ -z "${DISK_QUOTA_SIZE}" ]; then
  DISK_QUOTA_SIZE=20
fi

if [ -z "${DISK_QUOTA_FREQUENCY}" ]; then
  DISK_QUOTA_FREQUENCY=5
fi

if [ -z "${POSTGRES_SCHEMA}" ]; then
    POSTGRES_SCHEMA=public
fi

if [ -z "${SSL}" ]; then
  SSL=false
fi

if [ -z "${TOMCAT_EXTRAS}" ]; then
  TOMCAT_EXTRAS=false
fi

if [ -z "${ROOT_WEBAPP_REDIRECT}" ]; then
  ROOT_WEBAPP_REDIRECT=false
fi

if [ -z "${HTTP_PORT}" ]; then
  HTTP_PORT=8080
fi

if [ -z "${HTTP_PROXY_NAME}" ]; then
  HTTP_PROXY_NAME=
fi

if [ -z "${HTTP_PROXY_PORT}" ]; then
  HTTP_PROXY_PORT=
fi

if [ -z "${HTTP_SCHEME}" ]; then
  HTTP_SCHEME=http
fi

if [ -z "${HTTPS_SCHEME}" ]; then
  HTTPS_SCHEME=https
fi

if [ -z "${HTTP_REDIRECT_PORT}" ]; then
  HTTP_REDIRECT_PORT=
fi

if [ -z "${HTTP_CONNECTION_TIMEOUT}" ]; then
  HTTP_CONNECTION_TIMEOUT=20000
fi

if [ -z "${HTTPS_PORT}" ]; then
  HTTPS_PORT=8443
fi

if [ -z "${HTTPS_MAX_THREADS}" ]; then
  HTTPS_MAX_THREADS=150
fi

if [ -z "${HTTPS_CLIENT_AUTH}" ]; then
  HTTPS_CLIENT_AUTH=
fi

if [ -z "${HTTPS_PROXY_NAME}" ]; then
  HTTPS_PROXY_NAME=
fi

if [ -z "${HTTPS_PROXY_PORT}" ]; then
  HTTPS_PROXY_PORT=
fi


if [ -z "${ENCODING}" ]; then
    ENCODING='UTF8'
fi

if [ -z "${TIMEZONE}" ]; then
    TIMEZONE='GMT'
fi

if [ -z "${LANGUAGE}" ]; then
    LANGUAGE='en'
fi

if [ -z "${REGION}" ]; then
    REGION='US'
fi

if [ -z "${COUNTRY}" ]; then
    COUNTRY='US'
fi

if [ -z "${CHARACTER_ENCODING}" ]; then
    CHARACTER_ENCODING='UTF-8'
fi

if [ -z "${CLUSTERING}" ]; then
    CLUSTERING=false
fi

if [ -z "${CLUSTER_DURABILITY}" ]; then
    CLUSTER_DURABILITY=true
fi

if [ -z "${BROKER_URL}" ]; then
    BROKER_URL=
fi

if [ -z "${READONLY}" ]; then
    READONLY=disabled
fi


if [ -z "${TOGGLE_MASTER}" ]; then
    TOGGLE_MASTER=true
fi

if [ -z "${TOGGLE_SLAVE}" ]; then
    TOGGLE_SLAVE=true
fi

if [ -z "${EMBEDDED_BROKER}" ]; then
    EMBEDDED_BROKER=enabled
fi

if [ -z "${CLUSTER_CONNECTION_RETRY_COUNT}" ]; then
    CLUSTER_CONNECTION_RETRY_COUNT=10
fi

if [ -z "${CLUSTER_CONNECTION_MAX_WAIT}" ]; then
    CLUSTER_CONNECTION_MAX_WAIT=500
fi

if [ -z "${DB_BACKEND}" ]; then
    DB_BACKEND=
fi

if [ -z "${LOGIN_STATUS}" ]; then
    LOGIN_STATUS=on
fi

if [ -z "${DISABLE_WEB_INTERFACE}" ]; then
    DISABLE_WEB_INTERFACE=false
fi

if [ -z "${RECREATE_DATADIR}" ]; then
    RECREATE_DATADIR=false
fi

if [ -z "${RECREATE_DISKQUOTA}" ]; then
    RECREATE_DISKQUOTA=false
fi

if [ -z "${RESET_ADMIN_CREDENTIALS}" ]; then
  RESET_ADMIN_CREDENTIALS=false
fi

if [ -z "${INITIAL_MEMORY}" ]; then
    INITIAL_MEMORY="2G"
fi

if [ -z "${MAXIMUM_MEMORY}" ]; then
    MAXIMUM_MEMORY="4G"
fi

if [ -z "${XFRAME_OPTIONS}" ]; then
    XFRAME_OPTIONS=true
fi

if [ -z "${REQUEST_TIMEOUT}" ]; then
    REQUEST_TIMEOUT=60
fi

if [ -z "${PARALLEL_REQUEST}" ]; then
    PARALLEL_REQUEST=100
fi

if [ -z "${GETMAP}" ]; then
    GETMAP=10
fi

if [ -z "${REQUEST_EXCEL}" ]; then
    REQUEST_EXCEL=4
fi

if [ -z "${SINGLE_USER}" ]; then
    SINGLE_USER=6
fi

if [ -z "${GWC_REQUEST}" ]; then
    GWC_REQUEST=16
fi

if [ -z "${WPS_REQUEST}" ]; then
    WPS_REQUEST='1000/d;30s'
fi

if [ -z "${USER_WMS_REQUEST}" ]; then
    USER_WMS_REQUEST='30/s'
fi

if [ -z "${THROTTLE_REQUEST_PER_IP}" ]; then
    THROTTLE_REQUEST_PER_IP=10
fi

file_env S3_SERVER_URL
if [ -z "${S3_SERVER_URL}" ]; then
    S3_SERVER_URL=''
fi

file_env 'S3_USERNAME'
if [ -z "${S3_USERNAME}" ]; then
    S3_USERNAME=''
fi

file_env 'S3_PASSWORD'
if [ -z "${S3_PASSWORD}" ]; then
    S3_PASSWORD=''
fi

if [ -z "${SAMPLE_DATA}" ]; then
    SAMPLE_DATA=false
fi

if [ -z "${GEOSERVER_FILEBROWSER_HIDEFS}" ]; then
    GEOSERVER_FILEBROWSER_HIDEFS=false
fi

if [ -z "${ALLOW_ENV_PARAMETRIZATION}" ]; then
    ALLOW_ENV_PARAMETRIZATION=false
fi

if [ -z "${GEOSERVER_LOG_PROFILE}" ]; then
    GEOSERVER_LOG_PROFILE=DEFAULT_LOGGING
fi

if [ -z "${GEOSERVER_LOG_DIR}" ]; then
    GEOSERVER_LOG_DIR=${GEOSERVER_DATA_DIR}/logs
fi

if [ -z "${ACTIVATE_ALL_COMMUNITY_EXTENSIONS}" ]; then
    ACTIVATE_ALL_COMMUNITY_EXTENSIONS=false
fi

if [ -z "${ACTIVATE_ALL_STABLE_EXTENSIONS}" ]; then
    ACTIVATE_ALL_STABLE_EXTENSIONS=false
fi

file_env TOMCAT_USER
if [ -z "${TOMCAT_USER}" ]; then
    TOMCAT_USER='tomcat'
fi

file_env GEOSERVER_ADMIN_USER
if [ -z "${GEOSERVER_ADMIN_USER}" ]; then
    GEOSERVER_ADMIN_USER='admin'
fi

if [ -z "${CSRF_WHITELIST}" ]; then
    CSRF_WHITELIST=
fi

if [ -z "${INITIAL_HEAP_OCCUPANCY_PERCENT}" ]; then
    INITIAL_HEAP_OCCUPANCY_PERCENT=45
fi

if [ -z "${ADDITIONAL_JAVA_STARTUP_OPTIONS}" ]; then
    ADDITIONAL_JAVA_STARTUP_OPTIONS=''
fi


if [ -z "${POSTGRES_JNDI}" ]; then
    POSTGRES_JNDI=false
fi

if [ -z "${SSL_MODE}" ]; then
    SSL_MODE=disable
fi

if [ -z ${HASHING_ALGORITHM} ];then
    HASHING_ALGORITHM='SHA-256'
fi

if [ -z "${USE_DATETIME_IN_SHAPEFILE}" ]; then
    USE_DATETIME_IN_SHAPEFILE=true
fi

if [ -z "${FORCE_DOWNLOAD_STABLE_EXTENSIONS}" ]; then
    FORCE_DOWNLOAD_STABLE_EXTENSIONS=false
fi

if [ -z "${FORCE_DOWNLOAD_COMMUNITY_EXTENSIONS}" ]; then
    FORCE_DOWNLOAD_COMMUNITY_EXTENSIONS=false
fi

if [ -z "${DISABLE_CORS}" ]; then
  DISABLE_CORS=false
fi

if [ -z "${DISABLE_SECURITY_FILTER}" ]; then
  DISABLE_SECURITY_FILTER=false
fi
if [ -z "${ACTIVATE_PROXY_HEADERS}" ]; then
  ACTIVATE_PROXY_HEADERS=false
fi

if [ -z "${UPDATE_LOGGING_PROFILES}" ]; then
  UPDATE_LOGGING_PROFILES=false
fi

if [ -z "${RELINQUISH_LOG4J_CONTROL}" ]; then
  RELINQUISH_LOG4J_CONTROL=false
fi

if [ -z "${USE_DEFAULT_CREDENTIALS}" ]; then
  USE_DEFAULT_CREDENTIALS=false
fi

if [ -z "${CHOWN_DATA_DIR}" ]; then
  CHOWN_DATA_DIR=true
fi

if [ -z "${CHOWN_GWC_DATA_DIR}" ]; then
  CHOWN_GWC_DATA_DIR=true
fi

if [ -z "${GEOSERVER_CONTEXT_ROOT}" ]; then
  # For runtime only, do not change at build-time.
  GEOSERVER_CONTEXT_ROOT=geoserver
fi

if [ -z "${SHOW_PASSWORD}" ]; then
  # For runtime only, do not change at build-time.
  SHOW_PASSWORD=true
fi

if [ -z "${RUN_AS_ROOT}" ]; then
  RUN_AS_ROOT=false
fi

if [ -z "${JDBC_CONFIG_ENABLED}" ]; then
  JDBC_CONFIG_ENABLED=true
fi

if [ -z "${JDBC_STORE_ENABLED}" ]; then
  JDBC_STORE_ENABLED=true
fi

if [ -z "${JDBC_IGNORE_PATHS}" ]; then
  JDBC_IGNORE_PATHS='data,jdbcstore,jdbcconfig,temp,tmp,logs,styles'
fi
# S3 Alias
file_env S3_ALIAS
if [ -z "${S3_ALIAS}" ]; then
  S3_ALIAS='alias'
fi

if [ -z "${GEOSERVER_REQUIRE_FILE}" ];then
  GEOSERVER_REQUIRE_FILE=''
fi

if [ -z "${RESET_MONITORING_LOGS}" ];then
  RESET_MONITORING_LOGS=false
fi

if [ -z "${MONITORING_AUDIT_ENABLED}" ];then
  MONITORING_AUDIT_ENABLED=false
fi
if [ -z "${MONITORING_AUDIT_ROLL_LIMIT}" ];then
  MONITORING_AUDIT_ROLL_LIMIT=20
fi
if [ -z "${MONITORING_STORAGE}" ];then
  MONITORING_STORAGE=memory
fi
if [ -z "${MONITORING_MODE}" ];then
  MONITORING_MODE=history
fi
if [ -z "${MONITORING_SYNC}" ];then
  MONITORING_SYNC=async
fi
if [ -z "${MONITORING_BODY_SIZE}" ];then
  MONITORING_BODY_SIZE=1024
fi
if [ -z "${MONITORING_BBOX_LOG_CRS}"  ];then
  MONITORING_BBOX_LOG_CRS=EPSG:4326
fi
if [ -z "${MONITORING_BBOX_LOG_LEVEL}" ];then
  MONITORING_BBOX_LOG_LEVEL=no_wfs
fi

if [ -z "${ENTITY_RESOLUTION_ALLOWLIST}" ];then
  ENTITY_RESOLUTION_ALLOWLIST="www.w3.org|schemas.opengis.net|www.opengis.net|inspire.ec.europa.eu/schemas"
fi

if [ -z "${GEOSERVER_DISABLE_STATIC_WEB_FILES}" ];then
  GEOSERVER_DISABLE_STATIC_WEB_FILES=true
fi


# Values can be INFO,SEVER,WARNING,CONFIG,FINE,FINER,FINEST,ALL
if [ -z "${CONSOLE_HANDLER_LEVEL}" ];then
  CONSOLE_HANDLER_LEVEL=INFO
fi

# Allows loging to files, default is to stdout
if [ -z "${LOGGING_STDOUT}" ];then
  LOGGING_STDOUT=true
fi