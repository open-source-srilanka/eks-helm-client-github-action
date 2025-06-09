# Contributing to EKS Helm Client GitHub Action

First off, thank you for considering contributing to the EKS Helm Client GitHub Action! It's people like you that make this tool better for everyone in the community.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How Can I Contribute?](#how-can-i-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Enhancements](#suggesting-enhancements)
  - [Your First Code Contribution](#your-first-code-contribution)
  - [Pull Requests](#pull-requests)
- [Development Setup](#development-setup)
- [Style Guides](#style-guides)
  - [Git Commit Messages](#git-commit-messages)
  - [Bash Style Guide](#bash-style-guide)
  - [Documentation Style Guide](#documentation-style-guide)
- [Testing](#testing)
- [Security](#security)
- [Community](#community)

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to [dinushchathurya21@gmail.com](mailto:dinushchathurya21@gmail.com).

## Getting Started

Before you begin:
- Have you read the [Code of Conduct](CODE_OF_CONDUCT.md)?
- Check out the [existing issues](https://github.com/open-source-srilanka/eks-helm-client-github-action/issues)
- Read the [README](../README.md) and [documentation](../docs/)

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible using the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md).

**Great Bug Reports** tend to have:
- A quick summary and/or background
- Steps to reproduce
  - Be specific!
  - Give sample code if you can
- What you expected would happen
- What actually happens
- Notes (possibly including why you think this might be happening, or stuff you tried that didn't work)

### Suggesting Enhancements

This section guides you through submitting an enhancement suggestion, including completely new features and minor improvements to existing functionality.

Before creating enhancement suggestions, please check the existing issues and discussions. When you are creating an enhancement suggestion, please include as many details as possible using the [feature request template](.github/ISSUE_TEMPLATE/feature_request.md).

**Great Enhancement Suggestions** tend to have:
- A clear use case
- An explanation of how it would benefit other users
- If possible, example usage or mockups

### Your First Code Contribution

Unsure where to begin contributing? You can start by looking through these beginner and help-wanted issues:

- [Beginner issues](https://github.com/open-source-srilanka/eks-helm-client-github-action/labels/good%20first%20issue) - issues which should only require a few lines of code, and a test or two
- [Help wanted issues](https://github.com/open-source-srilanka/eks-helm-client-github-action/labels/help%20wanted) - issues which should be a bit more involved than beginner issues

### Pull Requests

The process described here has several goals:
- Maintain the project's quality
- Fix problems that are important to users
- Engage the community in working toward the best possible EKS Helm Client
- Enable a sustainable system for maintainers to review contributions

Please follow these steps to have your contribution considered by the maintainers:

1. Follow all instructions in [the template](.github/PULL_REQUEST_TEMPLATE.md)
2. Follow the [style guides](#style-guides)
3. After you submit your pull request, verify that all [status checks](https://help.github.com/articles/about-status-checks/) are passing

## Development Setup

1. **Fork and Clone the Repository**
   ```bash
   git clone https://github.com/your-username/eks-helm-client-github-action.git
   cd eks-helm-client-github-action
   ```

2. **Create a Feature Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Set Up Development Environment**
   ```bash
   # Make scripts executable
   chmod +x scripts/*.sh
   chmod +x .github/scripts/**/*.sh
   
   # Install development dependencies (if any)
   # Currently, this action uses Docker, so ensure Docker is installed
   ```

4. **Build the Docker Image**
   ```bash
   docker build -t eks-helm-client:dev .
   ```

5. **Run Tests**
   ```bash
   # Unit tests
   ./tests/unit/test-entrypoint.sh
   ./tests/unit/test-health-check.sh
   ./tests/unit/test-templates.sh
   
   # Integration tests
   ./.github/scripts/testing/run-integration-tests.sh
   ```

## Style Guides

### Git Commit Messages

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests liberally after the first line
- Use conventional commits format when possible:
  - `feat:` for new features
  - `fix:` for bug fixes
  - `docs:` for documentation changes
  - `style:` for formatting, missing semicolons, etc
  - `refactor:` for code refactoring
  - `test:` for adding missing tests
  - `chore:` for maintenance tasks

Example:
```
feat: add support for private Helm registries

- Add authentication for Harbor, Nexus, and Artifactory
- Support both basic auth and token-based auth
- Add comprehensive error handling for registry failures

Fixes #123
```

### Bash Style Guide

We follow the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) with some modifications:

#### Key Points:

1. **Shebang**
   ```bash
   #!/bin/bash
   ```

2. **Error Handling**
   ```bash
   set -e  # Exit on error
   set -u  # Exit on undefined variable (when appropriate)
   set -o pipefail  # Fail on pipe errors
   ```

3. **Functions**
   ```bash
   # Good
   function_name() {
       local var_name="$1"
       local another_var="${2:-default}"
       
       # Function body
       echo "Processing: $var_name"
   }
   
   # Usage
   function_name "argument" "optional"
   ```

4. **Variables**
   ```bash
   # Constants (readonly)
   readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   readonly DEFAULT_TIMEOUT=300
   
   # Local variables
   local file_path="/tmp/test"
   
   # Global variables (avoid when possible)
   GLOBAL_STATE="active"
   ```

5. **Conditionals**
   ```bash
   # Good
   if [[ -n "${variable:-}" ]]; then
       echo "Variable is set"
   fi
   
   # Check file existence
   if [[ -f "$file_path" ]]; then
       echo "File exists"
   fi
   ```

6. **Logging**
   ```bash
   log_info() {
       echo -e "${BLUE}[INFO]${NC} $1" >&2
   }
   
   log_error() {
       echo -e "${RED}[ERROR]${NC} $1" >&2
   }
   ```

7. **Error Messages**
   ```bash
   if [[ -z "${CLUSTER_NAME:-}" ]]; then
       log_error "CLUSTER_NAME is required"
       log_error "Please provide either:"
       log_error "  - Input parameter: cluster-name"
       log_error "  - Environment variable: CLUSTER_NAME"
       exit 1
   fi
   ```

### Documentation Style Guide

1. **Markdown Files**
   - Use ATX-style headers (`#` not underlines)
   - Include a table of contents for long documents
   - Use code blocks with language specification
   - Include examples whenever possible

2. **Code Comments**
   ```bash
   # Function to configure EKS cluster access
   # This function retrieves cluster information from AWS EKS API
   # and generates a kubeconfig file for authentication
   configure_eks_access() {
       # Implementation
   }
   ```

3. **README Sections**
   - Keep examples concise and realistic
   - Include both basic and advanced usage
   - Provide troubleshooting guidance

## Testing

### Running Tests Locally

1. **Unit Tests**
   ```bash
   # Run all unit tests
   for test in tests/unit/test-*.sh; do
       bash "$test"
   done
   ```

2. **Integration Tests**
   ```bash
   # Build the Docker image
   docker build -t eks-helm-client:test .
   
   # Run integration tests
   ./.github/scripts/testing/run-integration-tests.sh
   ```

3. **Manual Testing**
   ```bash
   # Test with dry run
   docker run --rm \
     -e INPUT_CLUSTER_NAME="test-cluster" \
     -e INPUT_REGION="us-west-2" \
     -e INPUT_DRY_RUN="true" \
     -e INPUT_ARGS="helm list" \
     eks-helm-client:test
   ```

### Writing Tests

When adding new features, please include:

1. **Unit tests** for individual functions
2. **Integration tests** for end-to-end scenarios
3. **Documentation** with examples
4. **Error cases** to ensure proper error handling

Example test structure:
```bash
#!/bin/bash
# tests/unit/test-new-feature.sh

source "$(dirname "$0")/../../.github/scripts/testing/utils.sh"

test_new_feature() {
    # Test implementation
    local result
    result=$(new_feature "input")
    
    if [[ "$result" == "expected" ]]; then
        log_test_result "PASS" "New feature test"
        return 0
    else
        log_test_result "FAIL" "New feature test" "Expected 'expected', got '$result'"
        return 1
    fi
}

# Run test
test_new_feature
```

## Security

### Security Considerations

1. **Never commit secrets** or sensitive data
2. **Validate all inputs** to prevent injection attacks
3. **Use secure defaults** for all configurations
4. **Follow the principle of least privilege** for IAM permissions
5. **Clean up sensitive data** after use

### Reporting Security Issues

Please **DO NOT** create public GitHub issues for security vulnerabilities. Instead, please report them directly to [dinushchathurya21@gmail.com](mailto:dinushchathurya21@gmail.com).

## Community

### Getting Help

- 📧 Email: [dinushchathurya21@gmail.com](mailto:dinushchathurya21@gmail.com)
- 💬 Discussions: [GitHub Discussions](https://github.com/open-source-srilanka/eks-helm-client-github-action/discussions)
- 🐛 Issues: [GitHub Issues](https://github.com/open-source-srilanka/eks-helm-client-github-action/issues)

### Project Structure

```
eks-helm-client-github-action/
├── .github/              # GitHub-specific files
│   ├── workflows/        # CI/CD workflows
│   └── scripts/          # CI/CD scripts
├── docs/                 # Documentation
│   └── examples/         # Usage examples
├── scripts/              # Main action scripts
├── templates/            # Configuration templates
├── tests/                # Test files
│   ├── unit/            # Unit tests
│   └── integration/      # Integration tests
├── action.yml            # Action definition
├── Dockerfile            # Container definition
└── README.md            # Main documentation
```

### Release Process

1. **Version Numbering**: We use [Semantic Versioning](https://semver.org/)
2. **Release Branches**: Create from `main` branch
3. **Testing**: All tests must pass
4. **Documentation**: Update CHANGELOG.md
5. **Tag**: Create version tag (e.g., `v2.1.0`)

### Recognition

Contributors will be recognized in:
- The project README
- Release notes
- Special thanks in major releases

## Thank You!

Your contributions to open source make great things possible. Thank you for taking the time to contribute to the EKS Helm Client GitHub Action!

---

**Made with ❤️ by the Open Source Sri Lanka community**