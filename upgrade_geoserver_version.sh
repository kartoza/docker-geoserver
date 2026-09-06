#!/bin/bash


GS_VERSION="${1:-3.0.1}"
GS_NEW_VERSION="${2:-3.0.2}"
PUSH_CHANGES="${3:-TRUE}"


sed -i "s/${GS_VERSION}/${GS_NEW_VERSION}/g" "Dockerfile"

sed -i "s/${GS_VERSION}/${GS_NEW_VERSION}/g" "Advanced-Configuration.md"

sed -i "s/${GS_VERSION}/${GS_NEW_VERSION}/g" "Developer-Guidelines.md"

sed -i "s/${GS_VERSION}/${GS_NEW_VERSION}/g" "README.md"

sed -i "s/${GS_VERSION}/${GS_NEW_VERSION}/g" "./compose/.env"

sed -i  "s/${GS_VERSION}/${GS_NEW_VERSION}/g" "clustering/docker-compose.yml"

sed -i  "s/${GS_VERSION}/${GS_NEW_VERSION}/g" "clustering/docker-compose-external.yml"

# Github actions always install the latest versions

if [[ ${PUSH_CHANGES} =~ [Tt][Rr][Uu][Ee] ]];
  git commit -a -m "Upgraded the GeoServer instance from version ${GS_VERSION} to ${GS_NEW_VERSION}"
fi

