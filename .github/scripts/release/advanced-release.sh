#!/bin/bash
# .github/scripts/release/advanced-release.sh
# Advanced release operations (can be run separately)

set -e

# Function to validate action.yml
validate_action_yml() {
  echo "🔍 Validating action.yml..."
  
  if [[ ! -f "action.yml" ]]; then
    echo "❌ action.yml not found!"
    exit 1
  fi
  
  # Basic validation using grep (no external dependencies)
  if ! grep -q "^name:" action.yml; then
    echo "❌ action.yml missing 'name' field"
    exit 1
  fi
  
  if ! grep -q "^description:" action.yml; then
    echo "❌ action.yml missing 'description' field"
    exit 1
  fi
  
  echo "✅ action.yml validation passed"
}

# Function to run security scan
security_scan() {
  echo "🔒 Running security scan..."
  
  # Run Trivy if available
  if command -v trivy &> /dev/null; then
    trivy image --exit-code 1 --severity CRITICAL,HIGH test-action:latest
  else
    echo "⚠️ Trivy not installed, skipping security scan"
  fi
}

# Function to update version badges
update_badges() {
  local version=$1
  echo "📛 Updating version badges..."
  
  # Update README.md badges
  if [[ -f "README.md" ]]; then
    sed -i "s/badge\/version-v[0-9.]*-blue/badge\/version-v${version}-blue/g" README.md
    sed -i "s/badge\/release-v[0-9.]*/badge\/release-v${version}/g" README.md
  fi
}

# Function to create release announcement
create_announcement() {
  local version=$1
  local type=$2
  
  cat > RELEASE_ANNOUNCEMENT.md << EOF
# 🎉 EKS Helm Client v${version} Released!

We're excited to announce the release of EKS Helm Client GitHub Action v${version}.

## Highlights

$(if [[ "$type" == "stable" ]]; then
  echo "This is a **stable release** ready for production use."
else
  echo "This is a **release candidate** for testing and feedback."
fi)

## Installation

\`\`\`yaml
- uses: open-source-srilanka/eks-helm-client-github-action@v${version}
\`\`\`

## What's New

See the [full changelog](https://github.com/open-source-srilanka/eks-helm-client-github-action/releases/tag/v${version}).

## Support

- 📧 Email: dinushchathurya21@gmail.com
- 🐛 Issues: [GitHub Issues](https://github.com/open-source-srilanka/eks-helm-client-github-action/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/open-source-srilanka/eks-helm-client-github-action/discussions)
EOF
}

# Main execution based on command
case "${1:-help}" in
  validate)
    validate_action_yml
    ;;
  security)
    security_scan
    ;;
  badges)
    update_badges "$2"
    ;;
  announce)
    create_announcement "$2" "$3"
    ;;
  all)
    validate_action_yml
    security_scan
    update_badges "$2"
    create_announcement "$2" "$3"
    ;;
  help|*)
    echo "Usage: $0 [command] [args]"
    echo "Commands:"
    echo "  validate              - Validate action.yml"
    echo "  security              - Run security scan"
    echo "  badges <version>      - Update version badges"
    echo "  announce <ver> <type> - Create release announcement"
    echo "  all <version> <type>  - Run all operations"
    ;;
esac