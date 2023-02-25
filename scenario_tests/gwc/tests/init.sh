#!/bin/bash

export PGPASSWORD=${POSTGRES_PASS}

psql -d gis -p 5432 -U docker -h localhost -f /tests/init.sql
