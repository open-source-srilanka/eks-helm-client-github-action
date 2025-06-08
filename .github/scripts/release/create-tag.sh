#!/bin/bash
# .github/scripts/release/create-tag.sh
# Create git tags for the release

set -e

VERSION="${{ steps.setup.outputs.version }}"
RELEASE_TYPE="${{ steps.setup.outputs.release_type }}"

# Create version tag if it doesn't exist
if ! git rev-parse "v$VERSION" >/dev/null 2>&1; then
  git tag "v$VERSION"
  git push origin "v$VERSION"
fi

# Update major version tag for stable releases
if [[ "$RELEASE_TYPE" == "stable" ]]; then
  MAJOR_VERSION=$(echo $VERSION | cut -d. -f1)
  git tag -f "v$MAJOR_VERSION"
  git push -f origin "v$MAJOR_VERSION"
  echo "✅ Updated major version tag: v$MAJOR_VERSION"
fi