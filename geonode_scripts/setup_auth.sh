#!/bin/sh
sed -i.bak 's@<baseUrl>\([^<][^<]*\)</baseUrl>@<baseUrl>'"$DJANGO_URL"'</baseUrl>@'\
           ${GEOSERVER_DATA_DIR}/security/auth/geonodeAuthProvider/config.xml