#!/bin/bash

set -ex

INFLUX_ORG_ID=$(influx org find -n $(influx config --json | jq -r '.org') --json | jq -r '.[0].id')
INFLUX_TOKEN=$(influx config --json | jq -r '.token')

BUCKET_NAME=icestationzebra
TELEGRAF_NAME="$1"
TELEGRAF_ID=$(influx telegrafs --json | jq -r ".configurations[] | select(.name == \"$TELEGRAF_NAME\") | .id")

curl -v --request POST \
     $(influx config --json | jq -r '.url')/api/v2/authorizations \
     --header "Authorization: Token ${INFLUX_TOKEN}" \
     --header 'Content-type: application/json' \
     --data '{
  "status": "active",
  "description": "WRITE '"${BUCKET_NAME}"' / READ '"${TELEGRAF_NAME}"' telegraf config",
  "orgID": "'"${INFLUX_ORG_ID}"'",
  "permissions": [
    {
      "action": "read",
      "resource": {
        "orgID": "'"${INFLUX_ORG_ID}"'",
        "type": "telegrafs",
        "id": "'"${TELEGRAF_ID}"'"
      }
    },
    {
      "action": "write",
      "resource": {
        "orgID": "'"${INFLUX_ORG_ID}"'",
        "type": "buckets",
        "name": "'"${BUCKET_NAME}"'"
      }
    }
  ]
}'
