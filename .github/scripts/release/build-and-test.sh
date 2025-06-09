#!/bin/bash
# .github/scripts/release/build-and-test.sh
# Build and test the action before release

set -e

echo "🔨 Building Docker image..."
docker build -t test-action:$VERSION .

echo "🧪 Running basic tests..."
# Quick validation test
docker run --rm \
  -e INPUT_CLUSTER_NAME=test-cluster \
  -e INPUT_REGION=us-west-2 \
  -e INPUT_ARGS="echo 'Test successful'" \
  -e INPUT_DRY_RUN=true \
  -e INPUT_DEBUG=true \
  test-action:$VERSION

echo "✅ Build and test completed successfully"