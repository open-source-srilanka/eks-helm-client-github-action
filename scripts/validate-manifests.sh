#!/bin/bash
# Validate Kubernetes manifests

set -euo pipefail

MANIFEST_DIR="${1:-}"
NAMESPACE="${2:-default}"

if [[ -z "$MANIFEST_DIR" ]]; then
    echo "Usage: $0 <manifest-directory> [namespace]"
    exit 1
fi

echo "Validating manifests in: $MANIFEST_DIR"

# Validate with kubectl dry-run
find "$MANIFEST_DIR" -name "*.yaml" -o -name "*.yml" | while read -r manifest; do
    echo "Validating: $manifest"
    kubectl apply --dry-run=client -f "$manifest" --namespace="$NAMESPACE"
done

# Additional validation with kubeval (if available)
if command -v kubeval &> /dev/null; then
    echo "Running kubeval validation..."
    find "$MANIFEST_DIR" -name "*.yaml" -o -name "*.yml" | xargs kubeval
fi

echo "Manifest validation completed!"