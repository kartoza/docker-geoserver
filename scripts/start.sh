#!/bin/bash


if [[ ${SAMPLE_DATA} =~ [Tt][Rr][Uu][Ee] ]]; then \
  echo "Installing default data directory"
  cp -r ${CATALINA_HOME}/data/* ${GEOSERVER_DATA_DIR}
fi

# Install stable plugins
 for ext in $(echo "${STABLE_EXTENSIONS}" | tr ',' ' '); do
        echo "Enabling ${ext} for GeoServer"
        if [[  -z "${STABLE_EXTENSIONS}" ]]; then \
          echo "Do not install any plugins"
        else
            echo "Installing ${ext}.zip plugin"
            unzip /plugins/${ext}.zip -d /tmp/gs_plugin \
            && mv /tmp/gs_plugin/*.jar "${CATALINA_HOME}"/webapps/geoserver/WEB-INF/lib/ \
            && rm -rf /tmp/gs_plugin
        fi
done

# Install community modules plugins
 for ext in $(echo "${COMMUNITY_EXTENSIONS}" | tr ',' ' '); do
        echo "Enabling ${ext} for GeoServer"
        if [[  -z ${COMMUNITY_EXTENSIONS} ]]; then \
          echo "Do not install any plugins"
        else
            echo "Installing ${ext}.zip plugin"
            unzip /plugins/${ext}.zip -d /tmp/gs_plugin \
            && mv /tmp/gs_plugin/*.jar "${CATALINA_HOME}"/webapps/geoserver/WEB-INF/lib/ \
            && rm -rf /tmp/gs_plugin
        fi
done


if [[ -f "${GEOSERVER_DATA_DIR}"/controlflow.properties  ]]; then \
    rm "${GEOSERVER_DATA_DIR}"/controlflow.properties
fi;


cat > "${GEOSERVER_DATA_DIR}"/controlflow.properties <<EOF
timeout=${REQUEST_TIMEOUT}
ows.global=${PARARELL_REQUEST}
ows.wms.getmap=${GETMAP}
ows.wfs.getfeature.application/msexcel=${REQUEST_EXCEL}
user=${SINGLE_USER}
ows.gwc=${GWC_REQUEST}
user.ows.wps.execute=${WPS_REQUEST}
EOF

if [[ -f "${GEOSERVER_DATA_DIR}"/s3.properties  ]]; then \
    rm "${GEOSERVER_DATA_DIR}"/s3.properties
fi;


cat > "${GEOSERVER_DATA_DIR}"/s3.properties <<EOF
alias.s3.endpoint=${S3_SERVER_URL}
alias.s3.user=${S3_USERNAME}
alias.s3.password=${S3_PASSWORD}
EOF