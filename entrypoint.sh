#!/bin/bash
set -e

export CA_CERT=$(aws eks describe-cluster --region "$REGION_CODE" --name "$CLUSTER_NAME" --query "cluster.certificateAuthority.data" --output text)
export ENDPOINT_URL=$(aws eks describe-cluster --region "$REGION_CODE" --name "$CLUSTER_NAME" --query "cluster.endpoint" --output text)
cat /config.template | envsubst > /opt/kubernetes/config
export KUBECONFIG=/opt/kubernetes/config

exec "$@"
