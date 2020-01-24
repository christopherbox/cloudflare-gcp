#!/bin/bash

cloudflare_email=''
cloudflare_oauth=''

set -f
IFS='|'
DATA=($(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?status=active" -H "X-Auth-Email: $cloudflare_email" -H "X-Auth-Key: $cloudflare_oauth" -H "Content-Type: application/json" | jq -r '.result| map([.name, .id] | join("|")) | join("|")'))
set +f

tLen=${#DATA[@]}

for (( i=0; i<${tLen}; i+=2 ));
do
  echo "-----------------"
  echo "Zone: ${DATA[i]}"
  echo "ID: ${DATA[i+1]}"
  echo "Grabbing the logpush bucket names associated"
  BUCKET_NAME=($(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${DATA[i+1]}/logpush/jobs" -H "X-Auth-Email: $cloudflare_email" -H "X-Auth-Key: $cloudflare_oauth" -H "Content-Type: application/json" | jq -r '.result[].destination_conf'| awk -F "/" '{print $3}'))
  if [ -z "$BUCKET_NAME" ]
  then
    echo "There is no bucket associated with the zone ${data[i]}"
  else
    echo "GCP Bucket: $BUCKET_NAME"
    DATASET="CLOUDFLARE_DATASET"
    URL=$( echo "${DATA[i]}" | tr '.' '_' )
    TABLE=$URL
    REGION="us-central1"
    # You probably don't need to change this value:
    FN_NAME="Cloudflare-Storage-BigQuery-${URL^^}"
    #
    echo "Dataset: $DATASET"
    echo "Table: $TABLE"
    echo "Region: $REGION"
    echo "FN_NAME: $FN_NAME"
    gcloud functions deploy $FN_NAME \
      --quiet \
      --runtime nodejs8 \
      --trigger-resource $BUCKET_NAME \
      --trigger-event google.storage.object.finalize \
      --region=$REGION \
      --memory=1024MB \
      --entry-point=gcsbq \
      --set-env-vars DATASET=$DATASET,TABLE=$TABLE,SCHEMA="./schema.json"
  fi
  echo "---done loop $i ---"
done

    

