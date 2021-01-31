#!/usr/bin/env bash

repository=$1
tag=$2

if [[ -z $repository || -z $tag ]]; then
    >&2 echo "Usage: $0 <repository-name> <tag-suffix>"
    exit 1
fi

digest=$(cat image-name-with-digest | sed 's/.*@//')

if [[ -z $digest ]]; then
    >&2 echo "No digest found, exiting..."
    exit 1
fi

echo "fetching image with digest: $digest"

aws ecr batch-get-image \
  --repository-name=$1 \
  --image-ids=imageDigest=$digest \
  --query="images[0].imageManifest" \
  --output=text > manifest.json

echo 'saved manifest.json'

aws ecr put-image \
  --repository-name=$1 \
  --image-tag=$2 \
  --image-manifest=file://manifest.json

echo "successfully pushed $repository:$tag"