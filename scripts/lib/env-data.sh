#!/bin/bash


file_env() {
  local var="$1"
  local fileVar="${var}_FILE"
  local def="${2:-}"

  if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
    printf >&2 'error: both %s and %s are set (but are exclusive)\n' "$var" "$fileVar"
    exit 1
  fi

  local val="$def"
  if [ "${!var:-}" ]; then
    val="${!var}"
  elif [ "${!fileVar:-}" ]; then
    val="$(< "${!fileVar}")"
  fi

  export "$var"="$val"
  unset "$fileVar"
}

env_default() {
  local var="$1"
  local default="$2"

  if [[ -z "${!var:-}" ]]; then
    export "${var}=${default}"
  fi
}



# ---------------------------------------------
# Core flags
# ---------------------------------------------
env_default ENABLE_JSONP true
env_default MAX_FILTER_RULES 20
env_default OPTIMIZE_LINE_WIDTH false
env_default WMS_DIR_INTEGRATION true
env_default REQUIRE_TILED_PARAMETER true
env_default WMSC_ENABLED true
env_default DISKQUOTA_DISABLED false
env_default TMS_ENABLED true
env_default SECURITY_ENABLED false
env_default DISK_QUOTA_SIZE 20
env_default DISK_QUOTA_FREQUENCY 5
env_default POSTGRES_SCHEMA public
env_default SSL false
env_default TOMCAT_EXTRAS false
env_default ROOT_WEBAPP_REDIRECT false
env_default HTTP_PORT 8080
env_default HTTP_PROXY_NAME ''
env_default HTTP_PROXY_PORT ''
env_default HTTP_SCHEME http
env_default HTTPS_SCHEME https
env_default HTTP_REDIRECT_PORT ''
env_default HTTP_CONNECTION_TIMEOUT 20000
env_default HTTPS_PORT 8443
env_default HTTPS_MAX_THREADS 150
env_default HTTPS_CLIENT_AUTH ''
env_default HTTPS_PROXY_NAME ''
env_default HTTPS_PROXY_PORT ''

# ---------------------------------------------
# Locale / encoding
# ---------------------------------------------
env_default ENCODING UTF8
env_default TIMEZONE GMT
env_default LANGUAGE en
env_default REGION US
env_default COUNTRY US
env_default CHARACTER_ENCODING UTF-8

# ---------------------------------------------
# Clustering / broker
# ---------------------------------------------
env_default CLUSTERING false
env_default CLUSTER_DURABILITY true
env_default BROKER_URL ''
env_default READONLY disabled
env_default TOGGLE_MASTER true
env_default TOGGLE_SLAVE true
env_default EMBEDDED_BROKER enabled
env_default CLUSTER_CONNECTION_RETRY_COUNT 10
env_default CLUSTER_CONNECTION_MAX_WAIT 500

# ---------------------------------------------
# Application flags
# ---------------------------------------------
env_default DB_BACKEND ''
env_default LOGIN_STATUS on
env_default DISABLE_WEB_INTERFACE false
env_default RECREATE_DATADIR false
env_default RECREATE_DISKQUOTA false
env_default RESET_ADMIN_CREDENTIALS false

env_default INITIAL_MEMORY 2G
env_default MAXIMUM_MEMORY 4G
env_default XFRAME_OPTIONS true

# ---------------------------------------------
# Request limits
# ---------------------------------------------
env_default REQUEST_TIMEOUT 60
env_default PARALLEL_REQUEST 100
env_default GETMAP 10
env_default REQUEST_EXCEL 4
env_default SINGLE_USER 6
env_default GWC_REQUEST 16
env_default WPS_REQUEST '1000/d;30s'
env_default USER_WMS_REQUEST '30/s'
env_default THROTTLE_REQUEST_PER_IP 10

# ---------------------------------------------
# S3
# ---------------------------------------------
file_env S3_SERVER_URL
env_default S3_SERVER_URL ''

file_env S3_USERNAME
env_default S3_USERNAME ''

file_env S3_PASSWORD
env_default S3_PASSWORD ''

# S3 Alias
file_env S3_ALIAS
env_default S3_ALIAS alias

# ---------------------------------------------
# GeoServer features
# ---------------------------------------------
env_default SAMPLE_DATA false
env_default GEOSERVER_FILEBROWSER_HIDEFS false
env_default ALLOW_ENV_PARAMETRIZATION false
env_default GEOSERVER_LOG_PROFILE ''
env_default GEOSERVER_LOG_DIR "${GEOSERVER_DATA_DIR}/logs"

env_default ACTIVATE_ALL_COMMUNITY_EXTENSIONS false
env_default ACTIVATE_ALL_STABLE_EXTENSIONS false

file_env TOMCAT_USER
env_default TOMCAT_USER tomcat

env_default CSRF_WHITELIST ''
env_default INITIAL_HEAP_OCCUPANCY_PERCENT 45
env_default ADDITIONAL_JAVA_STARTUP_OPTIONS ''

env_default POSTGRES_JNDI_NAME postgres
env_default POSTGRES_JNDI false
env_default SSL_MODE disable
env_default HASHING_ALGORITHM SHA-256
env_default USE_DATETIME_IN_SHAPEFILE true

env_default FORCE_DOWNLOAD_STABLE_EXTENSIONS false
env_default FORCE_DOWNLOAD_COMMUNITY_EXTENSIONS false

env_default DISABLE_CORS false
env_default DISABLE_SECURITY_FILTER false
env_default ACTIVATE_PROXY_HEADERS false
env_default UPDATE_LOGGING_PROFILES false
env_default RELINQUISH_LOG4J_CONTROL false
env_default USE_DEFAULT_CREDENTIALS false

env_default CHOWN_DATA_DIR true
env_default CHOWN_GWC_DATA_DIR true

# Runtime only
env_default GEOSERVER_CONTEXT_ROOT geoserver
env_default SHOW_PASSWORD true
env_default RUN_AS_ROOT false

env_default JDBC_CONFIG_ENABLED true
env_default JDBC_STORE_ENABLED true
env_default JDBC_IGNORE_PATHS 'data,jdbcstore,jdbcconfig,temp,tmp,logs,styles'

env_default GEOSERVER_REQUIRE_FILE ''
env_default RESET_MONITORING_LOGS false

# ---------------------------------------------
# Monitoring
# ---------------------------------------------
env_default MONITORING_AUDIT_ENABLED false
env_default MONITORING_AUDIT_ROLL_LIMIT 20
env_default MONITORING_STORAGE memory
env_default MONITORING_MODE history
env_default MONITORING_SYNC async
env_default MONITORING_BODY_SIZE 1024
env_default MONITORING_BBOX_LOG_CRS EPSG:4326
env_default MONITORING_BBOX_LOG_LEVEL no_wfs

# ---------------------------------------------
# Data dir loader
# ---------------------------------------------
env_default GEOSERVER_DATA_DIR_LOADER_ENABLED true
env_default GEOSERVER_DATA_DIR_LOADER_THREADS 0

# ---------------------------------------------
# Logging
# ---------------------------------------------
env_default CONSOLE_HANDLER_LEVEL INFO
env_default LOGGING_STDOUT true
env_default GEOSERVER_SECURITY_MODE preserve

# ---------------------------------------------
# Security / sandbox
# ---------------------------------------------
env_default GEOSERVER_FILESYSTEM_SANDBOX ''

# ---------------------------------------------
# Telemetry
# ---------------------------------------------
env_default TELEMETRY_TRACING_ENABLED false
env_default TELEMETRY_METRICS_ENABLED false
env_default TELEMETRY_METRICS_PORT 12345
env_default OTEL_SERVICE_NAME geoserver