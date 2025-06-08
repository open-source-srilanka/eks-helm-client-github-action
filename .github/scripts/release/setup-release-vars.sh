#!/bin/bash
# .github/scripts/release/setup-release-vars.sh
# Setup release variables based on workflow trigger

set -e

# Determine version and release type
if [[ "${{ github.event_name }}" == "workflow_dispatch" ]]; then
  VERSION="${{ github.event.inputs.version }}"
  RELEASE_TYPE="${{ github.event.inputs.release_type }}"
elif [[ "${{ github.event_name }}" == "push" && "${{ github.ref_type }}" == "tag" ]]; then
  VERSION="${{ github.ref_name }}"
  VERSION="${VERSION#v}"
  if [[ "$VERSION" == *"-rc"* ]]; then
    RELEASE_TYPE="rc"
  else
    RELEASE_TYPE="stable"
  fi
fi

# Validate version format
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-rc\.[0-9]+)?$ ]]; then
  echo "Invalid version format: $VERSION"
  exit 1
fi

# Set outputs
echo "version=$VERSION" >> $GITHUB_OUTPUT
echo "release_type=$RELEASE_TYPE" >> $GITHUB_OUTPUT
echo "tag_name=v$VERSION" >> $GITHUB_OUTPUT

if [[ "$RELEASE_TYPE" == "rc" ]]; then
  echo "is_prerelease=true" >> $GITHUB_OUTPUT
else
  echo "is_prerelease=false" >> $GITHUB_OUTPUT
fi

echo "🚀 Releasing version: $VERSION ($RELEASE_TYPE)"