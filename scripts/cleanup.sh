#!/bin/bash
# Cleanup script for removing temporary files and resources

set -euo pipefail

echo "Cleaning up temporary files and resources..."

# Remove temporary files
rm -f /tmp/helm-*.json
rm -f /tmp/helm-*.yaml
rm -f /tmp/helm-output.txt

# Clean Helm cache
if [[ -d "/opt/helm/cache" ]]; then
    rm -rf /opt/helm/cache/*
fi

# Clean kubectl cache
if [[ -d "/opt/kubernetes" ]]; then
    rm -f /opt/kubernetes/config
fi

echo "Cleanup completed!"