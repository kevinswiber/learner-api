#!/bin/sh

if [[ -z "$JOB_NAME" ]]; then
    echo "JOB_NAME is required to execute this script."
    exit 1
fi

if [[ -z "$POSTMAN_API_KEY" ]]; then
    echo "POSTMAN_API_KEY is required to execute this script."
    exit 1
fi

if [[ -z "$BRANCH_NAME" ]]; then
    echo "BRANCH_NAME is required to execute this script."
    exit 1
fi

JOB_NAME="${JOB_NAME%/*}" # take only the first part of the job name

api_id=$(curl -s -H "X-API-Key: $POSTMAN_API_KEY" \
    "https://api.getpostman.com/apis" | \
    jq -r --arg JOB_NAME "$JOB_NAME" \
    '.apis[] | select(.name | contains($JOB_NAME)) | .id')

default_api_version_name_and_branch=$(curl -s -H "X-API-Key: $POSTMAN_API_KEY" \
    "https://api.getpostman.com/apis/$api_id/versions" | \
    jq -r \
    '[.versions[] | select(.name | contains("default:true")) | .name + "," + (.name | match("branch:(\\S+)") | .captures | map(.string)[0])][0]')

default_api_version_name="${default_api_version_name_and_branch%,*}"
git_default_branch_name="${default_api_version_name_and_branch##*,}"

[[ $(expr "$BRANCH_NAME" : "PR-") != 0 ]] && api_version_prefix="pr" && BRANCH_NAME=$(echo "$BRANCH_NAME" | awk '{ print substr( $0, 4 ) }') || api_version_prefix="branch"
[[ "$git_default_branch_name" != "$BRANCH_NAME" ]] && api_version_name="$api_version_prefix:$BRANCH_NAME" || api_version_name="$default_api_version_name"

echo "job name: $JOB_NAME"
echo "api id: $api_id"
echo "default branch: $git_default_branch_name"
echo "branch name: $BRANCH_NAME"
echo "api version name: $api_version_name"


api_version_id=$(curl -s -H "X-API-Key: $POSTMAN_API_KEY" \
    "https://api.getpostman.com/apis/$api_id/versions" | \
    jq -r --arg API_VERSION_NAME "$api_version_name" \
    '.versions[] | select(.name | contains($API_VERSION_NAME)) | .id')

if [ -z "$api_version_id" ]; then
    echo "api version name not found, defaulting to: $default_api_version_name"
    api_version_name="$default_api_version_name"
    api_version_id=$(curl -s -H "X-API-Key: $POSTMAN_API_KEY" \
        "https://api.getpostman.com/apis/$api_id/versions" | \
        jq -r --arg API_VERSION_NAME "$api_version_name" \
        '.versions[] | select(.name | contains($API_VERSION_NAME)) | .id')
fi

echo "api_version_id: $api_version_id"

integration_test_relation_id=$(curl -s -H "X-API-Key: $POSTMAN_API_KEY" \
    "https://api.getpostman.com/apis/$api_id/versions/$api_version_id/integrationtest" | \
    jq -r '.integrationtest[] | .id')

echo "integration_test_relation_id: $integration_test_relation_id"

curl -s -H "X-API-Key: $POSTMAN_API_KEY" \
    "https://api.getpostman.com/apis/$api_id/versions/$api_version_id/integrationtest/$integration_test_relation_id" | \
    jq --arg API_VERSION_NAME "$api_version_name" \
    'select(.versionTag.name | contains($API_VERSION_NAME)) | .collection' > postman_collection.json

if [[ $(jq 'has("info")' ./postman_collection.json) == "true" ]]; then
    echo 'success: collection written'
else
    echo "error: tagged collection not found.  Did you remember to tag the collection with the API Version?"
    exit 1
fi

environment_id=$(curl -s -H "X-API-Key: $POSTMAN_API_KEY" \
    "https://api.getpostman.com/apis/$api_id/versions/$api_version_id/environment" | \
    jq -r '.environment[] | .id')

echo "environment_id: $environment_id"
curl -s -H "X-API-Key: $POSTMAN_API_KEY" \
    "https://api.getpostman.com/environments/$environment_id" | \
    jq '.environment' > postman_environment.json

if [[ -n ./postman_environment.json && ! -z "$environment_id" ]]; then
    echo 'success: environment written'
else
    echo "warning: environment not found.  Did you remember to add the environment to the API Version?"
    echo "using empty environment instead"
    echo '{"values":[]}' > ./postman_environment.json
fi