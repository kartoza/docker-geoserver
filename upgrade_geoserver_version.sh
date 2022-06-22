#!/bin/bash


GS_VERSION=$1
if [  -f "${GS_VERSION}" ]; then
    rm "${GS_VERSION}"
fi


GS_NEW_VERSION=$2
if [  -f "${GS_NEW_VERSION}" ]; then
    rm "${GS_NEW_VERSION}"
fi

sed -i "s/${GS_VERSION}/${GS_NEW_VERSION}/g" "Dockerfile"

sed -i "s/${GS_VERSION}/${GS_NEW_VERSION}/g" "README.md"

sed -i "s/${GS_VERSION}/${GS_NEW_VERSION}/g" ".env"

sed -i  "s/${GS_VERSION}/${GS_NEW_VERSION}/g" "clustering/docker-compose.yml"

git commit -a -m "Upgraded GeoServer from version ${GS_VERSION} to ${GS_NEW_VERSION}"

