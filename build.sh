#!/bin/bash

set -e

[ $# -ne 1 ] && echo "must pass the following arguments: IMAGE_URL" && exit 1

IMAGE_URL=$1

docker build -t $IMAGE_URL .
docker push $IMAGE_URL

kubectl apply -f k8s/rbac.yaml

sed "s~IMAGE_URL%%~$IMAGE_URL~" k8s/cronjob.yaml | kubectl apply -f -
