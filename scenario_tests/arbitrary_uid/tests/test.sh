#!/usr/bin/env bash

set -e

pushd /tests >/dev/null
python3 -m unittest -v "${TEST_CLASS}"
popd >/dev/null
