#!/bin/bash
# Security scanning for the Docker image

set -euo pipefail

IMAGE_NAME="${1:-eks-helm-client:latest}"

echo "Running security scan on: $IMAGE_NAME"

# Scan with Trivy (if available)
if command -v trivy &> /dev/null; then
    echo "Running Trivy security scan..."
    trivy image "$IMAGE_NAME"
fi

# Check for common security issues
echo "Checking Dockerfile security practices..."

# Verify non-root user
if docker run --rm "$IMAGE_NAME" whoami | grep -q "runner"; then
    echo "✅ Running as non-root user"
else
    echo "❌ Not running as non-root user"
fi

# Check for latest base image
if docker history "$IMAGE_NAME" | grep -q "projectoss/alpine:3.20"; then
    echo "✅ Using recent Alpine base image"
else
    echo "⚠️  Consider updating base image"
fi

echo "Security scan completed!"