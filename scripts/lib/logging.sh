#!/usr/bin/env bash

log() {
  echo "$0:${BASH_LINENO[*]}:" "$@"
}

log4j_logging() {
  if [[ ! -f "${CATALINA_HOME}/log4j.properties" ]]; then
    if [[ -f "${EXTRA_CONFIG_DIR}/log4j.properties" ]]; then
      envsubst < "${EXTRA_CONFIG_DIR}/log4j.properties" > "${CATALINA_HOME}/log4j.properties"
    else
      if [[ ${CLUSTERING} =~ [Tt][Rr][Uu][Ee] ]]; then
        export LOG_PATH="${CLUSTER_CONFIG_DIR}/geoserver-${HOSTNAME}.log"
      else
        export LOG_PATH="${GEOSERVER_LOG_DIR}/geoserver.log"
      fi
      envsubst < /build_data/log4j.properties > "${CATALINA_HOME}/log4j.properties"
    fi
  fi
}

set_logging_xml() {
  cat > "${GEOSERVER_LOG_SETTINGS_PATH}" <<EOF
<logging>
  <level>${GEOSERVER_LOG_PROFILE}</level>
  <location>${LOG_PATH}</location>
  <stdOutLogging>true</stdOutLogging>
</logging>
EOF
}

geoserver_logging() {
  export GEOSERVER_LOG_SETTINGS_PATH="${GEOSERVER_DATA_DIR}/logging.xml"

  if [[ ${CLUSTERING} =~ [Tt][Rr][Uu][Ee] ]]; then
    export LOG_PATH="${CLUSTER_CONFIG_DIR}/geoserver-${HOSTNAME}.log"
  else
    create_dir "${GEOSERVER_LOG_DIR}"
    export LOG_PATH="${GEOSERVER_LOG_DIR}/geoserver.log"
  fi

  if [[ -z "${GEOSERVER_LOG_PROFILE}" ]]; then
    if [[ -f "${GEOSERVER_LOG_SETTINGS_PATH}" ]]; then
      GEOSERVER_LOG_PROFILE=$(sed -n 's:.*<level>\(.*\)</level>.*:\1:p' "${GEOSERVER_LOG_SETTINGS_PATH}" | head -n 1)
    else
      GEOSERVER_LOG_PROFILE=DEFAULT_LOGGING
    fi
  fi

  set_logging_xml
  [[ -f "${LOG_PATH}" ]] || touch "${LOG_PATH}"
}

tomcat_logging() {
  if [[ -f "${EXTRA_CONFIG_DIR}/logging.properties" ]]; then
    envsubst < "${EXTRA_CONFIG_DIR}/logging.properties" > "${CATALINA_HOME}/conf/logging.properties"
  else
    envsubst < /build_data/logging.properties > "${CATALINA_HOME}/conf/logging.properties"
  fi
}

setup_monitoring() {

  if [[ -f "${EXTRA_CONFIG_DIR}"/monitor.properties ]]; then
        envsubst < "${EXTRA_CONFIG_DIR}"/monitor.properties > "${GEOSERVER_DATA_DIR}"/monitoring/monitor.properties
  else

  cat > "${GEOSERVER_DATA_DIR}"/monitoring/monitor.properties <<EOF
audit.enabled=${MONITORING_AUDIT_ENABLED}
audit.roll_limit=${MONITORING_AUDIT_ROLL_LIMIT}
storage=${MONITORING_STORAGE}
mode=${MONITORING_MODE}
sync=${MONITORING_SYNC}
maxBodySize=${MONITORING_BODY_SIZE}
bboxLogCrs=${MONITORING_BBOX_LOG_CRS}
bboxLogLevel=${MONITORING_BBOX_LOG_LEVEL}
EOF
  fi

}