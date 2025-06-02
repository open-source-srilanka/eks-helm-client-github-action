#!/bin/bash
# Test different deployment scenarios

set -euo pipefail

echo "Testing various deployment scenarios..."

# Test 1: Basic deployment
echo "Test 1: Basic Helm deployment"
docker run --rm \
    -e INPUT_CLUSTER_NAME=test-cluster \
    -e INPUT_REGION=us-west-2 \
    -e INPUT_HELM_COMMANDS="helm version" \
    -e INPUT_DEBUG=true \
    eks-helm-client:latest

# Test 2: Private cluster mode
echo "Test 2: Private cluster configuration"
docker run --rm \
    -e INPUT_CLUSTER_NAME=private-cluster \
    -e INPUT_REGION=us-west-2 \
    -e INPUT_PRIVATE_CLUSTER=true \
    -e INPUT_HELM_COMMANDS="helm version" \
    -e INPUT_DEBUG=true \
    eks-helm-client:latest

# Test 3: Validation mode
echo "Test 3: Validation and dry-run mode"
docker run --rm \
    -e INPUT_CLUSTER_NAME=test-cluster \
    -e INPUT_REGION=us-west-2 \
    -e INPUT_DRY_RUN=true \
    -e INPUT_VALIDATE_MANIFESTS=true \
    -e INPUT_HELM_COMMANDS="helm version" \
    -e INPUT_DEBUG=true \
    eks-helm-client:latest

echo "All test scenarios completed!"