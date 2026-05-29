#!/usr/bin/env bash
set -euo pipefail

pip install --quiet requests beautifulsoup4 >/dev/null 2>&1

python /scripts/get_latest_geoserver.py