#!/bin/sh

if [[ -z "$JOB_NAME" ]]; then
    echo "JOB_NAME is required to execute this script."
    exit 1
fi

if [[ -z "$POSTMAN_API_KEY" ]]; then
    echo "POSTMAN_API_KEY is required to execute this script.  Get one here: https://go.postman.co/settings/me/api-keys"
    exit 1
fi

if [[ -z "$BRANCH_NAME" ]]; then
    echo "BRANCH_NAME is required to execute this script."
    exit 1
fi

if [[ -z "$TEST_TYPE" ]]; then
    TEST_TYPE=testsuite
fi

if [[ -z "$GIT_REF_TYPE" ]]; then
    GIT_REF_TYPE=branch
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
    '[.versions[] | select(.name | test("(^|\\s)default:true($|\\s)")) | .name + "," + (.name | match("(?:^|\\s)branch:(\\S+)(?:$|\\s)") | .captures | map(.string)[0])][0] // empty')

default_api_version_name="${default_api_version_name_and_branch%,*}"
git_default_branch_name="${default_api_version_name_and_branch##*,}"

[[ $(expr "$BRANCH_NAME" : "PR-") != 0 ]] && api_version_prefix="pr" && BRANCH_NAME=$(echo "$BRANCH_NAME" | awk '{ print substr( $0, 4 ) }') || api_version_prefix="$GIT_REF_TYPE"
[[ "$git_default_branch_name" != "$BRANCH_NAME" ]] && api_version_name="$api_version_prefix:$BRANCH_NAME" || api_version_name="$default_api_version_name"

echo "job name: ${JOB_NAME%/*}"
echo "provided group: $GROUP"
echo "api id: $api_id"
echo "default branch: $git_default_branch_name"
echo "branch name: $BRANCH_NAME"
echo "api version name: $api_version_name"

[[ -f ./postman_collection.json ]] && rm ./postman_collection.json
[[ -f ./postman_environment.json ]] && rm ./postman_environment.json

api_version_id=$(curl -s -H "X-API-Key: $POSTMAN_API_KEY" \
    "https://api.getpostman.com/apis/$api_id/versions" | \
    jq -r --arg API_VERSION_NAME "$api_version_name" \
    '.versions[] | select(.name | test("(^|\\s)" + $API_VERSION_NAME + "($|\\s)")) | .id // empty')

if [ -z "$api_version_id" ]; then
    echo "api version name not found, defaulting to: $default_api_version_name"
    api_version_name="$default_api_version_name"
    api_version_id=$(curl -s -H "X-API-Key: $POSTMAN_API_KEY" \
        "https://api.getpostman.com/apis/$api_id/versions" | \
        jq -r --arg API_VERSION_NAME "$api_version_name" \
        '.versions[] | select(.name | test("(^|\\s)" + $API_VERSION_NAME + "($|\\s)")) | .id // empty')
fi

echo "api version id: $api_version_id"

if [[ ! -z "$GROUP" ]]; then
    test_relation_id=$(curl -s -H "X-API-Key: $POSTMAN_API_KEY" \
        "https://api.getpostman.com/apis/$api_id/versions/$api_version_id/$TEST_TYPE" | \
        jq -r --arg TEST_TYPE "$TEST_TYPE" --arg GROUP "$GROUP" '[.[$TEST_TYPE][] | select(.name | test("(^|\\s)group:" + $GROUP + "(\\s|$)")) | .id][0] // empty')

    if [[ -z "$test_relation_id" ]]; then
        >&2 echo "error: group not found in test type."
        exit 1
    fi
fi

if [[ -z "$test_relation_id" ]]; then
    test_relation_id=$(curl -s -H "X-API-Key: $POSTMAN_API_KEY" \
        "https://api.getpostman.com/apis/$api_id/versions/$api_version_id/$TEST_TYPE" | \
        jq -r --arg TEST_TYPE "$TEST_TYPE" '[.[$TEST_TYPE][] | .id][0] // empty')
fi

if [[ -z "$test_relation_id" ]]; then
    >&2 echo "error: default test not found on api version."
    exit 1
fi

echo "test relation id: $test_relation_id"

curl -s -H "X-API-Key: $POSTMAN_API_KEY" \
    "https://api.getpostman.com/apis/$api_id/versions/$api_version_id/$TEST_TYPE/$test_relation_id" | \
    jq --arg API_VERSION_NAME "$api_version_name" \
    'select(.versionTag.name | [$API_VERSION_NAME, "CURRENT"] | any) // empty' > postman_version.tmp.json

if [[ $(wc -c ./postman_version.tmp.json | awk '{print $1}') == '0' ]]; then
    >&2 echo "error: test not found on api version."
    exit 1
fi

tag=$(jq -r '.versionTag.name // empty' ./postman_version.tmp.json)
group=$(jq -r '(.name | capture("(?:^|\\s)group:(?<group>\\S+)(?:\\s|$)") | .group) // empty' ./postman_version.tmp.json)

if [[ "$tag" == "CURRENT" ]]; then
    echo "warning: tagged collection not found, falling back to CURRENT version of collection."
fi

echo "test version tag: $tag"
echo "found group: $group"

jq '.collection' ./postman_version.tmp.json > ./postman_collection.json

if [[ $(wc -c ./postman_collection.json | awk '{print $1}') == '0' ]]; then
    >&2 echo "error: test collection not found."
    exit 1
fi

rm ./postman_version.tmp.json

echo 'success: collection written'

if [[ ! -z "$group" ]]; then
    environment_id=$(curl -s -H "X-API-Key: $POSTMAN_API_KEY" \
        "https://api.getpostman.com/apis/$api_id/versions/$api_version_id/environment" | \
        jq -r --arg GROUP "$group" '[.environment[] | select(.name | test("(^|\\s)group:" + $GROUP + "(\\s|$)")) | .id][0] // empty')
fi

if [[ -z "$environment_id" ]]; then
    environment_id=$(curl -s -H "X-API-Key: $POSTMAN_API_KEY" \
        "https://api.getpostman.com/apis/$api_id/versions/$api_version_id/environment" | \
        jq -r '[.environment[] | select(.name | test("(^|\\s)default:true(\\s|$)")) | .id][0]')
fi

echo "environment id: $environment_id"

if [[ ! -z "$environment_id" ]]; then
    curl -s -H "X-API-Key: $POSTMAN_API_KEY" \
        "https://api.getpostman.com/environments/$environment_id" | \
        jq '.environment' > postman_environment.json
fi

if [[ $(wc -c ./postman_environment.json | awk '{print $1}') != '0' && ! -z "$environment_id" ]]; then
    echo 'success: environment written'
else
    echo "warning: environment not found.  Did you remember to add the environment to the API Version?"
    echo "using empty environment instead"
    echo '{"values":[]}' > ./postman_environment.json
fi