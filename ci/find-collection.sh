#!/bin/sh

[[ $(expr "$BRANCH_NAME" : "PR-") != 0 ]] && api_version_prefix="pr" && BRANCH_NAME=$(echo "$BRANCH_NAME" | awk '{ print substr( $0, 4 ) }') || api_version_prefix="branch"
[[ "$DEFAULT_BRANCH" != "$BRANCH_NAME" ]] && api_version_name="${api_version_prefix}:${BRANCH_NAME}" || api_version_name="$DEFAULT_API_VERSION"

echo "default branch: ${DEFAULT_BRANCH}"
echo "branch name: ${BRANCH_NAME}"
echo "api version name: ${api_version_name}"
echo "api id: ${API_ID}"

api_version_id=$(curl -s -H "X-API-Key: ${POSTMAN_API_KEY}" \
    "https://api.getpostman.com/apis/${API_ID}/versions" | \
    jq -r --arg API_VERSION_NAME "${api_version_name}" \
    '.versions[] | select(.name | contains($API_VERSION_NAME)) | .id')

if [ -z "$api_version_id" ]; then
    echo "api version not found, defaulting to: ${DEFAULT_API_VERSION}"
    api_version_id=$(curl -s -H "X-API-Key: ${POSTMAN_API_KEY}" \
        "https://api.getpostman.com/apis/${API_ID}/versions" | \
        jq -r --arg API_VERSION_NAME "${DEFAULT_API_VERSION}" \
        '.versions[] | select(.name | contains($API_VERSION_NAME)) | .id')
fi

echo "api_version_id: ${api_version_id}"

# if no api_version_id, exit with error.

relation_id=$(curl -s -H "X-API-Key: ${POSTMAN_API_KEY}" \
    "https://api.getpostman.com/apis/${API_ID}/versions/${api_version_id}/integrationtest" | \
    jq -r '.integrationtest[] | .id')

# if no relation_id, exit with error.

echo "relation_id: ${relation_id}"

# should check response and exit with error on non-200.
curl -s -H "X-API-Key: ${POSTMAN_API_KEY}" \
    "https://api.getpostman.com/apis/${API_ID}/versions/${api_version_id}/integrationtest/${relation_id}" | \
    jq --arg API_VERSION_NAME "${api_version_name}" \
    'select(.versionTag.name | contains($API_VERSION_NAME)) | .collection' > postman_collection.json

if [[ $(jq 'has("info")' ./postman_collection.json) == "true" ]]; then
    echo 'success: collection written'
else
    echo "error: tagged collection not found.  Did you remember to tag the collection with the API Version?"
    exit 1
fi