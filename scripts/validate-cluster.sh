#!/bin/bash
# Validate EKS cluster connectivity and permissions

set -euo pipefail

CLUSTER_NAME="${1:-}"
REGION="${2:-}"

if [[ -z "$CLUSTER_NAME" || -z "$REGION" ]]; then
    echo "Usage: $0 <cluster-name> <region>"
    exit 1
fi

echo "Validating cluster connectivity..."

# Check AWS credentials
echo "Checking AWS credentials..."
aws sts get-caller-identity

# Check cluster exists and is accessible
echo "Checking cluster exists and is accessible..."
aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION"

# Test kubectl connectivity
echo "Testing kubectl connectivity..."
kubectl get nodes

# Check required permissions
echo "Checking required permissions..."
kubectl auth can-i create deployments
kubectl auth can-i create services
kubectl auth can-i create ingresses

echo "Cluster validation completed successfully!"