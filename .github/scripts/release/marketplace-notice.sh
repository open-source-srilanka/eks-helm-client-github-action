#!/bin/bash
# .github/scripts/release/marketplace-notice.sh
# Display marketplace publication notice

set -e

VERSION="${{ steps.setup.outputs.version }}"
RELEASE_TYPE="${{ steps.setup.outputs.release_type }}"
TAG_NAME="${{ steps.setup.outputs.tag_name }}"

echo "🎉 Release v$VERSION created!"
echo ""
echo "📦 Release Type: $RELEASE_TYPE"
echo "🏷️ Tag: $TAG_NAME"
echo "🔗 Release URL: ${{ github.server_url }}/${{ github.repository }}/releases/tag/$TAG_NAME"
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
  echo "- **Release URL**: [$TAG_NAME](${{ github.server_url }}/${{ github.repository }}/releases/tag/$TAG_NAME)"
} >> $GITHUB_STEP_SUMMARY