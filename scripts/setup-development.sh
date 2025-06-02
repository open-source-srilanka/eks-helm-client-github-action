#!/bin/bash
# Setup development environment

set -euo pipefail

echo "Setting up development environment..."

# Install development dependencies
apk add --no-cache \
    make \
    shellcheck \
    hadolint

# Setup Git hooks (if in development)
if [[ -d ".git" ]]; then
    echo "Setting up Git hooks..."
    cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Pre-commit hook for code quality

echo "Running pre-commit checks..."

# Shellcheck for shell scripts
find . -name "*.sh" -type f -exec shellcheck {} \;

# Hadolint for Dockerfile
hadolint Dockerfile

echo "Pre-commit checks passed!"
EOF
    chmod +x .git/hooks/pre-commit
fi

echo "Development environment setup completed!"