#!/bin/bash

dockerize -wait "tcp://${DB_HOST}:5432"  -timeout 60s /bin/bash  /scripts/entrypoint.sh