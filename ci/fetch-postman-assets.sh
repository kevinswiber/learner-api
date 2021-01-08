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

job_label="job:${JOB_NAME%/*}" # take only the first part of the job name

api_id=$(curl -s -H "X-API-Key: $POSTMAN_API_KEY" \
    "https://api.getpostman.com/apis" | \
    jq -r --arg JOB_NAME "$job_label" \
    '.apis[] | select(.name | test("(^|\\s)" + $JOB_NAME + "($|\\s)")) | .id')

if [[ -z "$api_id" ]]; then
    >&2 echo "error: no api is tagged with the label $job_label"
    exit 1
fi

default_api_version_name_and_branch=$(curl -s -H "X-API-Key: $POSTMAN_API_KEY" \
    "https://api.getpostman.com/apis/$api_id/versions" | \
    jq -r \
    '[.versions[] | select(.name | test("(^|\\s)default:true($|\\s)")) | .name + "," + (.name | match("(?:^|\\s)branch:(\\S+)(?:$|\\s)") | .captures | map(.string)[0])][0]')

default_api_version_name="${default_api_version_name_and_branch%,*}"
git_default_branch_name="${default_api_version_name_and_branch##*,}"

[[ $(expr "$BRANCH_NAME" : "PR-") != 0 ]] && api_version_prefix="pr" && BRANCH_NAME=$(echo "$BRANCH_NAME" | awk '{ print substr( $0, 4 ) }') || api_version_prefix="branch"
[[ "$git_default_branch_name" != "$BRANCH_NAME" ]] && api_version_name="$api_version_prefix:$BRANCH_NAME" || api_version_name="$default_api_version_name"

echo "job name: ${JOB_NAME%/*}"
echo "api id: $api_id"
echo "default branch: $git_default_branch_name"
echo "branch name: $BRANCH_NAME"
echo "api version name: $api_version_name"

[[ -f ./postman_collection.json ]] && rm ./postman_collection.json
[[ -f ./postman_environment.json ]] && rm ./postman_environment.json

api_version_id=$(curl -s -H "X-API-Key: $POSTMAN_API_KEY" \
    "https://api.getpostman.com/apis/$api_id/versions" | \
    jq -r --arg API_VERSION_NAME "$api_version_name" \
    '.versions[] | select(.name | test("(^|\\s)" + $API_VERSION_NAME + "($|\\s)")) | .id')

if [ -z "$api_version_id" ]; then
    echo "api version name not found, defaulting to: $default_api_version_name"
    api_version_name="$default_api_version_name"
    api_version_id=$(curl -s -H "X-API-Key: $POSTMAN_API_KEY" \
        "https://api.getpostman.com/apis/$api_id/versions" | \
        jq -r --arg API_VERSION_NAME "$api_version_name" \
        '.versions[] | select(.name | test("(^|\\s)" + $API_VERSION_NAME + "($|\\s)") | .id')
fi

echo "api version id: $api_version_id"

integration_test_relation_id=$(curl -s -H "X-API-Key: $POSTMAN_API_KEY" \
    "https://api.getpostman.com/apis/$api_id/versions/$api_version_id/integrationtest" | \
    jq -r '.integrationtest[] | .id')

echo "integration test relation id: $integration_test_relation_id"

curl -s -H "X-API-Key: $POSTMAN_API_KEY" \
    "https://api.getpostman.com/apis/$api_id/versions/$api_version_id/integrationtest/$integration_test_relation_id" | \
    jq --arg API_VERSION_NAME "$api_version_name" \
    'select(.versionTag.name | [$API_VERSION_NAME, "CURRENT"] | any)' > postman_version.tmp.json

if [[ $(wc -c ./postman_version.tmp.json | awk '{print $1}') == '0' ]]; then
    >&2 echo "error: integration test not found on api version."
    exit 1
fi

tag=$(jq -r '.versionTag.name' ./postman_version.tmp.json)

if [[ "$tag" == "CURRENT" ]]; then
    echo "warning: tagged collection not found, falling back to CURRENT version of collection."
fi

echo "integration test version tag: $tag"

jq '.collection' ./postman_version.tmp.json > ./postman_collection.json

if [[ $(wc -c ./postman_collection.json | awk '{print $1}') == '0' ]]; then
    >&2 echo "error: integration test collection not found."
    exit 1
fi

rm ./postman_version.tmp.json

echo 'success: collection written'

environment_id=$(curl -s -H "X-API-Key: $POSTMAN_API_KEY" \
    "https://api.getpostman.com/apis/$api_id/versions/$api_version_id/environment" | \
    jq -r '.environment[] | .id')

echo "environment id: $environment_id"
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