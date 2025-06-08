#!/bin/bash
# .github/scripts/release/generate-changelog.sh
# Generate changelog for the release

set -e

VERSION="${{ steps.setup.outputs.version }}"
RELEASE_TYPE="${{ steps.setup.outputs.release_type }}"

# Get last tag
LAST_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")

# Generate changelog
{
  echo "## EKS Helm Client v$VERSION"
  echo ""
  
  if [[ "$RELEASE_TYPE" == "rc" ]]; then
    echo "### ⚠️ Release Candidate"
    echo ""
    echo "This is a release candidate for testing. Not recommended for production use."
    echo ""
  fi
  
  echo "### 📋 Changes"
  echo ""
  
  if [[ -n "$LAST_TAG" ]]; then
    git log $LAST_TAG..HEAD --pretty=format:"- %s (%h)" --no-merges
  else
    echo "- Initial release"
  fi
  
  echo ""
  echo ""
  echo "### 🚀 Usage"
  echo ""
  echo '```yaml'
  echo "- name: Deploy to EKS"
  echo "  uses: ${{ github.repository }}@v$VERSION"
  echo "  with:"
  echo "    cluster-name: my-cluster"
  echo "    region: us-west-2"
  echo "    args: |"
  echo "      helm upgrade --install my-app ./chart"
  echo '```'
  echo ""
  echo "### 📚 Documentation"
  echo ""
  echo "- [README](https://github.com/${{ github.repository }}/blob/v$VERSION/README.md)"
  echo "- [Migration Guide](https://github.com/${{ github.repository }}/blob/v$VERSION/docs/MIGRATION.md)"
  echo "- [Examples](https://github.com/${{ github.repository }}/tree/v$VERSION/docs/examples)"
  echo ""
  echo "---"
  echo ""
  echo "**Full Changelog**: https://github.com/${{ github.repository }}/compare/$LAST_TAG...v$VERSION"
} > changelog.md

# Set output
echo 'changelog<<EOF' >> $GITHUB_OUTPUT
cat changelog.md >> $GITHUB_OUTPUT
echo 'EOF' >> $GITHUB_OUTPUT