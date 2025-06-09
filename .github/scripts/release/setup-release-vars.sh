#!/bin/bash
# .github/scripts/release/setup-release-vars.sh
# Setup release variables based on workflow trigger

set -e

# Determine version and release type
if [[ "$EVENT_NAME" == "workflow_dispatch" ]]; then
  VERSION="$INPUT_VERSION"
elif [[ "$EVENT_NAME" == "push" && "$REF_TYPE" == "tag" ]]; then
  VERSION="$REF_NAME"
  VERSION="${VERSION#v}"
fi

# Determine release type based on version string
if [[ "$VERSION" == *"-rc"* ]]; then
  RELEASE_TYPE="rc"
else
  RELEASE_TYPE="stable"
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