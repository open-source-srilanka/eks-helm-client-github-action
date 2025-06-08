# Makefile for release operations
# Place this in the root directory

.PHONY: help release-rc release-stable test-release setup-scripts

# Default version for testing
VERSION ?= 2.0.0
RC_VERSION ?= $(VERSION)-rc.1

help:
	@echo "Release Management Commands:"
	@echo "  make setup-scripts      - Setup release scripts permissions"
	@echo "  make test-release       - Test release process locally"
	@echo "  make release-rc         - Create RC release (VERSION=$(RC_VERSION))"
	@echo "  make release-stable     - Create stable release (VERSION=$(VERSION))"
	@echo "  make validate           - Validate action.yml"
	@echo "  make changelog          - Generate changelog"
	@echo ""
	@echo "Examples:"
	@echo "  make release-rc VERSION=2.2.0"
	@echo "  make release-stable VERSION=2.1.0"

setup-scripts:
	@echo "Setting up release scripts..."
	@chmod +x .github/scripts/release/*.sh
	@echo "✅ Scripts are now executable"

test-release:
	@echo "Testing release process..."
	@export GITHUB_OUTPUT=/tmp/github-output && \
	export GITHUB_STEP_SUMMARY=/tmp/github-summary && \
	echo "Testing with version $(VERSION)..." && \
	.github/scripts/release/advanced-release.sh validate && \
	echo "✅ Release test passed"

release-rc: setup-scripts
	@echo "Creating RC release $(RC_VERSION)..."
	@git tag -a v$(RC_VERSION) -m "Release candidate v$(RC_VERSION)"
	@echo "✅ Tagged v$(RC_VERSION)"
	@echo "Run 'git push origin v$(RC_VERSION)' to trigger release workflow"

release-stable: setup-scripts
	@echo "Creating stable release $(VERSION)..."
	@git tag -a v$(VERSION) -m "Release v$(VERSION)"
	@echo "✅ Tagged v$(VERSION)"
	@echo "Run 'git push origin v$(VERSION)' to trigger release workflow"

validate:
	@.github/scripts/release/advanced-release.sh validate

changelog:
	@echo "Generating changelog for $(VERSION)..."
	@export GITHUB_OUTPUT=/tmp/github-output && \
	.github/scripts/release/generate-changelog.sh && \
	cat /tmp/github-output

# Development helpers
.PHONY: docker-build docker-test clean

docker-build:
	@echo "Building Docker image..."
	@docker build -t eks-helm-client:test .

docker-test: docker-build
	@echo "Testing Docker image..."
	@docker run --rm \
		-e INPUT_CLUSTER_NAME=test-cluster \
		-e INPUT_REGION=us-west-2 \
		-e INPUT_ARGS="echo 'Test successful'" \
		-e INPUT_DRY_RUN=true \
		eks-helm-client:test

clean:
	@echo "Cleaning up..."
	@rm -f /tmp/github-output /tmp/github-summary
	@docker rmi eks-helm-client:test 2>/dev/null || true
	@echo "✅ Cleanup complete"