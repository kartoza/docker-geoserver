#!/usr/bin/env bash
set -euo pipefail

pip install --quiet requests >/dev/null 2>&1

python /scripts/get_latest_tomcat.py