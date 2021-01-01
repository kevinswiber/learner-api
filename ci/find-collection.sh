#!/bin/sh

[[ "$DEFAULT_BRANCH" != "$BRANCH_NAME" ]] && branch_id="branch: ${BRANCH_NAME}" || branch_id="${DEFAULT_API_VERSION}"

echo "default branch: ${DEFAULT_BRANCH}"
echo "branch name: ${BRANCH_NAME}"
echo "branch id: ${branch_id}"
echo "api id: ${API_ID}"

api_version_id=$(curl -s -H "X-API-Key: ${POSTMAN_API_KEY}" \
    "https://api.getpostman.com/apis/${API_ID}/versions" | \
    jq -r --arg BRANCH_ID "${branch_id}" \
    '.versions[] | select(.name == $BRANCH_ID) | .id')

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
    jq --arg BRANCH_ID "${branch_id}" \
    'select(.versionTag.name == $BRANCH_ID) | .collection' > postman_collection.json

if [[ $(jq 'has("info")' ./postman_collection.json) == "true" ]]; then
    echo 'success: collection written'
else
    echo "error: tagged collection not found.  Did you remember to tag the collection with the API Version?"
    exit 1
fi