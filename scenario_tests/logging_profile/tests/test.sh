#!/usr/bin/env bash

source /scripts/env-data.sh

set -euo pipefail

# Ensure EXPECTED is set
: "${EXPECTED_LOGGING_PROFILE:?EXPECTED_LOGGING_PROFILE environment variable must be set}"

# Extract value between <level>...</level> using sed
level=$(sed -n 's:.*<level>\(.*\)</level>.*:\1:p' "${GEOSERVER_DATA_DIR}"/logging.xml)

# Compare and fail if not equal
if [[ "$level" != "$EXPECTED_LOGGING_PROFILE" ]]; then
  echo "ERROR: Logging profile level mismatch at $CONTAINER_NAME. Found: '$level', EXPECTED_LOGGING_PROFILE: '$EXPECTED_LOGGING_PROFILE'" >&2
  exit 1
fi

echo "PASS: Test case passed at $CONTAINER_NAME. Logging profile level matches EXPECTED_LOGGING_PROFILE value: $level"
