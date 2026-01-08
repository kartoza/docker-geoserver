#!/usr/bin/env bash

############################################
# Helper functions containing
# postgres_ready_status
# postgres_ssl_setup
# create_gwc_tile_tables
# setup_jdbc_db_config
# setup_jdbc_db_store
############################################

postgres_ready_status() {
  until psql -h "$1" -p "$2" -U "$3" -d "$4" -c '\dt' >/dev/null 2>&1; do
    sleep 1
  done
}

postgres_ssl_setup() {
  case "${SSL_MODE}" in
    verify-ca|verify-full)
      export PARAMS="sslmode=${SSL_MODE}&sslcert=${SSL_CERT_FILE}&sslkey=${SSL_KEY_FILE}&sslrootcert=${SSL_CA_FILE}"
      ;;
    *)
      export PARAMS="sslmode=${SSL_MODE}"
      ;;
  esac
}

function create_gwc_tile_tables(){
  HOST="$1"
  PORT="$2"
  USER="$3"
  DB="$4"
  POSTGRES_SCHEMA="$5"
  if [ "${POSTGRES_SCHEMA}" != 'public' ]; then
   psql -d "$DB" -p "$PORT" -U "$USER" -h "$HOST" -c "CREATE SCHEMA IF NOT EXISTS ${POSTGRES_SCHEMA}"
   psql -d "$DB" -p "$PORT" -U "$USER" -h "$HOST" -c "CREATE TABLE IF NOT EXISTS ${POSTGRES_SCHEMA}.tileset(key character varying(320) NOT NULL,layer_name character varying(128),gridset_id character varying(32) ,blob_format character varying(64) ,parameters_id character varying(41) ,bytes numeric(21,0) NOT NULL DEFAULT 0,CONSTRAINT tileset_pkey PRIMARY KEY (key))"
   psql -d "$DB" -p "$PORT" -U "$USER" -h "$HOST" -c "CREATE TABLE IF NOT EXISTS $POSTGRES_SCHEMA.tilepage(key character varying(320) NOT NULL,tileset_id character varying(320),page_z smallint,page_x integer,page_y integer,creation_time_minutes integer,frequency_of_use double precision,last_access_time_minutes integer,fill_factor double precision,num_hits numeric(64,0),CONSTRAINT tilepage_pkey PRIMARY KEY (key),CONSTRAINT tilepage_tileset_id_fkey FOREIGN KEY (tileset_id) REFERENCES $POSTGRES_SCHEMA.tileset (key) MATCH SIMPLE ON UPDATE NO ACTION ON DELETE CASCADE)"
  fi

}

setup_jdbc_db_config() {
    if [[ ${ext} == 'jdbcconfig-plugin' ]];then
        if [[  ${DB_BACKEND} =~ [Pp][Oo][Ss][Tt][Gg][Rr][Ee][Ss] ]]; then
            PGPASSWORD="${POSTGRES_PASS}"
            export PGPASSWORD
            postgres_ready_status "${HOST}" "${POSTGRES_PORT}" "${POSTGRES_USER}" "$POSTGRES_DB"
            create_dir "${GEOSERVER_DATA_DIR}"/jdbcconfig
            cp -rn /build_data/jdbcconfig/scripts "${GEOSERVER_DATA_DIR}"/jdbcconfig/
            postgres_ssl_setup
            export SSL_PARAMETERS=${PARAMS}
            if [[ -f "${EXTRA_CONFIG_DIR}"/jdbcconfig.properties ]]; then
              envsubst < "${EXTRA_CONFIG_DIR}"/jdbcconfig.properties > "${GEOSERVER_DATA_DIR}"/jdbcconfig/jdbcconfig.properties
            else
              envsubst < /build_data/jdbcconfig/jdbcconfig.properties > "${GEOSERVER_DATA_DIR}"/jdbcconfig/jdbcconfig.properties
              sed -i '/^jndiName=/d' "${GEOSERVER_DATA_DIR}"/jdbcconfig/jdbcconfig.properties
              if [[ ${POSTGRES_JNDI} =~ [Tt][Rr][Uu][Ee] ]];then
                # Set jndiName if POSTGRES_JNDI is set to true
                echo "jndiName=java:comp/env/jdbc/postgres" >> "${GEOSERVER_DATA_DIR}"/jdbcconfig/jdbcconfig.properties
              fi
            fi

            check_jdbc_config_table=$(psql -d "$POSTGRES_DB" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -h "$HOST" -tAc "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'object_property')")
            if [[  ${check_jdbc_config_table} = "t" ]]; then
              sed -i 's/initdb=true/initdb=false/g' "${GEOSERVER_DATA_DIR}"/jdbcconfig/jdbcconfig.properties
              sed -i 's/import=true/import=false/g' "${GEOSERVER_DATA_DIR}"/jdbcconfig/jdbcconfig.properties
            fi
        else
            echo "skipping jdbc config and will use default settings"
        fi
    fi
}

setup_jdbc_db_store() {
    if [[ ${ext} == 'jdbcstore-plugin' ]];then
        PGPASSWORD="${POSTGRES_PASS}"
        export PGPASSWORD
        postgres_ready_status "${HOST}" "${POSTGRES_PORT}" "${POSTGRES_USER}" "$POSTGRES_DB"
        if [[  ${DB_BACKEND} =~ [Pp][Oo][Ss][Tt][Gg][Rr][Ee][Ss] ]]; then
            create_dir "${GEOSERVER_DATA_DIR}"/jdbcstore
            create_dir "${GEOSERVER_DATA_DIR}"/jdbcconfig
            cp -rn /build_data/jdbcstore/scripts "${GEOSERVER_DATA_DIR}"/jdbcstore/
            cp -rn /build_data/jdbcconfig/scripts "${GEOSERVER_DATA_DIR}"/jdbcconfig/
            postgres_ssl_setup
            export SSL_PARAMETERS=${PARAMS}
            if [[ -f "${EXTRA_CONFIG_DIR}"/jdbcconfig.properties ]]; then
              envsubst < "${EXTRA_CONFIG_DIR}"/jdbcconfig.properties > "${GEOSERVER_DATA_DIR}"/jdbcconfig/jdbcconfig.properties
            else
              envsubst < /build_data/jdbcconfig/jdbcconfig.properties > "${GEOSERVER_DATA_DIR}"/jdbcconfig/jdbcconfig.properties
            fi
            if [[ -f "${EXTRA_CONFIG_DIR}"/jdbcstore.properties ]]; then
              envsubst < "${EXTRA_CONFIG_DIR}"/jdbcstore.properties > "${GEOSERVER_DATA_DIR}"/jdbcstore/jdbcstore.properties
            else
              envsubst < /build_data/jdbcstore/jdbcstore.properties > "${GEOSERVER_DATA_DIR}"/jdbcstore/jdbcstore.properties
              sed -i '/^jndiName=/d' "${GEOSERVER_DATA_DIR}"/jdbcstore/jdbcstore.properties
              if [[ ${POSTGRES_JNDI} =~ [Tt][Rr][Uu][Ee] ]];then
                # Set jndiName if POSTGRES_JNDI is set to true
                echo "jndiName=java:comp/env/jdbc/postgres" >> "${GEOSERVER_DATA_DIR}"/jdbcstore/jdbcstore.properties
              fi
            fi

            check_jdbc_store_table=$(psql -d "$POSTGRES_DB" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" -h "${HOST}" -tAc "SELECT EXISTS(SELECT 1 from information_schema.tables where table_name = 'resources')")
            if [[  ${check_jdbc_store_table} = "t" ]]; then
              sed -i 's/initdb=true/initdb=false/g' "${GEOSERVER_DATA_DIR}"/jdbcstore/jdbcstore.properties
              sed -i 's/import=true/import=false/g' "${GEOSERVER_DATA_DIR}"/jdbcstore/jdbcstore.properties
            fi
            check_jdbc_config_table=$(psql -d "$POSTGRES_DB" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -h "$HOST" -tAc "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'object_property')")
            if [[  ${check_jdbc_config_table} = "t" ]]; then
              sed -i 's/initdb=true/initdb=false/g' "${GEOSERVER_DATA_DIR}"/jdbcconfig/jdbcconfig.properties
              sed -i 's/import=true/import=false/g' "${GEOSERVER_DATA_DIR}"/jdbcconfig/jdbcconfig.properties
            fi
        else
          echo "skipping jdbc store config and will use default settings"
        fi
    fi
}