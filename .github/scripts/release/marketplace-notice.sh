#!/bin/bash
# .github/scripts/release/marketplace-notice.sh
# Display marketplace publication notice

set -e

echo "🎉 Release v$VERSION created!"
echo ""
echo "📦 Release Type: $RELEASE_TYPE"
echo "🏷️ Tag: $TAG_NAME"
echo "🔗 Release URL: $GITHUB_SERVER_URL/$GITHUB_REPOSITORY/releases/tag/$TAG_NAME"
echo ""

if [[ "$RELEASE_TYPE" == "stable" ]]; then
  MAJOR_VERSION=$(echo $VERSION | cut -d. -f1)
  echo "✅ This stable release will be published to GitHub Marketplace as LATEST"
  echo "👥 Users can reference: @v$VERSION or @v$MAJOR_VERSION"
else
  echo "🧪 This RC release will be published to GitHub Marketplace as PRERELEASE"
  echo "👥 Users can reference: @v$VERSION for testing"
fi

# Create workflow summary
{
  echo "## 📦 Release Summary"
  echo "- **Version**: v$VERSION"
  echo "- **Type**: $RELEASE_TYPE"
  echo "- **Marketplace Status**: Published"
  echo "- **Release URL**: [$TAG_NAME]($GITHUB_SERVER_URL/$GITHUB_REPOSITORY/releases/tag/$TAG_NAME)"
} >> $GITHUB_STEP_SUMMARY