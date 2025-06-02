#!/bin/bash
# Backup current Helm releases

set -euo pipefail

NAMESPACE="${1:-all-namespaces}"
BACKUP_PATH="${2:-/tmp/helm-backup}"

mkdir -p "$BACKUP_PATH"

if [[ "$NAMESPACE" == "all-namespaces" ]]; then
    echo "Backing up all Helm releases..."
    helm list --all-namespaces -o json > "$BACKUP_PATH/all-releases.json"
else
    echo "Backing up Helm releases in namespace: $NAMESPACE"
    helm list -n "$NAMESPACE" -o json > "$BACKUP_PATH/${NAMESPACE}-releases.json"
fi

# Get detailed information for each release
helm list --all-namespaces --short | while read -r release namespace; do
    if [[ -n "$release" && -n "$namespace" ]]; then
        echo "Backing up release: $release in namespace: $namespace"
        helm get all "$release" -n "$namespace" > "$BACKUP_PATH/${namespace}-${release}.yaml"
    fi
done

echo "Backup completed: $BACKUP_PATH"