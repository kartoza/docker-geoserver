#!/usr/bin/env bash
set -euo pipefail

apt update;apt install -y gdal-bin

gdal_version=$(gdalinfo --version | awk '{print $2}' | tr -d ',')

echo "The GDAL version is $gdal_version"
echo "gdal_version=$gdal_version" >> "/github_output/github_output.txt"