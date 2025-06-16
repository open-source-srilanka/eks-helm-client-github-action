#!/bin/bash
set -e

# This script is the entrypoint for the GitHub Action Docker container.
# It sets up the Kubeconfig for EKS access and then executes the commands passed to the action.

echo "--- Configuring AWS EKS Kubeconfig ---"

# Export CA_CERT: Fetches the certificate authority data for the EKS cluster.
# This is crucial for kubectl to trust the EKS API server.
# REGION_CODE and CLUSTER_NAME are expected to be set as environment variables
# by the GitHub Actions workflow (e.g., via the `env` block in `action.yml`).
export CA_CERT=$(aws eks describe-cluster --region "$REGION_CODE" --name "$CLUSTER_NAME" --query "cluster.certificateAuthority.data" --output text)
if [ -z "$CA_CERT" ]; then
  echo "Error: Could not retrieve EKS cluster certificate authority data. Check REGION_CODE and CLUSTER_NAME."
  exit 1
fi

# Export ENDPOINT_URL: Fetches the endpoint URL for the EKS cluster.
export ENDPOINT_URL=$(aws eks describe-cluster --region "$REGION_CODE" --name "$CLUSTER_NAME" --query "cluster.endpoint" --output text)
if [ -z "$ENDPOINT_URL" ]; then
  echo "Error: Could not retrieve EKS cluster endpoint URL. Check REGION_CODE and CLUSTER_NAME."
  exit 1
fi

echo "EKS Cluster Endpoint: $ENDPOINT_URL"

# Generate Kubernetes configuration file (/opt/kubernetes/config)
# This file tells kubectl how to connect to the EKS cluster.
# It uses /config.template (expected to be present in the Docker image)
# and substitutes environment variables (CA_CERT, ENDPOINT_URL).
# The KUBECONFIG environment variable is already set in the Dockerfile
# to point to this location.
cat /config.template | envsubst > /opt/kubernetes/config

# Verify the generated Kubeconfig (optional, for debugging)
echo "Generated Kubeconfig:"
cat /opt/kubernetes/config
echo "----------------------"

# Ensure KUBECONFIG environment variable is correctly set for subsequent commands
export KUBECONFIG=/opt/kubernetes/config

echo "--- Executing Helm Commands ---"
# Execute the commands passed as arguments to the action (e.g., Helm commands)
# The "$@" expands to all positional parameters passed to the script,
# which corresponds to the `args` input in your `action.yml`.
exec "$@"
