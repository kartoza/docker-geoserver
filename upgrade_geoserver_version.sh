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

IFS='.' read -r MAJOR MINOR BUGFIX <<<"$GS_NEW_VERSION"

sed -i '' "s/minor: .*/minor: $MINOR/g; s/patch: .*/patch: $BUGFIX/g" .github/workflows/deploy-image.yaml

sed -i '' "s/minor: .*/minor: $MINOR/g; s/patch: .*/patch: $BUGFIX/g" .github/workflows//build-latest.yaml

git commit -a -m "Upgraded the GeoServer instance from version ${GS_VERSION} to ${GS_NEW_VERSION}"

