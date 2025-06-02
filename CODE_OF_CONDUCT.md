# Contributing to EKS Helm Client GitHub Action

We welcome contributions to the EKS Helm Client GitHub Action! This document outlines how to contribute to the project, including development setup, coding standards, and the contribution process.

## 🚀 Getting Started

### Prerequisites

Before contributing, ensure you have:

- **Docker** installed for building and testing the action
- **Git** for version control
- **AWS CLI** configured for testing with real EKS clusters
- **kubectl** for Kubernetes cluster interaction
- **Helm** for chart management
- **ShellCheck** for shell script linting
- **Hadolint** for Dockerfile linting

### Development Environment Setup

1. **Fork and clone the repository**:
   ```bash
   git clone https://github.com/your-username/eks-helm-client-github-action.git
   cd eks-helm-client-github-action
   ```

2. **Set up development tools**:
   ```bash
   # Run the development setup script
   ./scripts/setup-development.sh
   ```

3. **Build the Docker image**:
   ```bash
   docker build -t eks-helm-client:dev .
   ```

4. **Run basic tests**:
   ```bash
   ./scripts/test-scenarios.sh
   ```

## 🛠️ Development Guidelines

### Code Style and Standards

#### Shell Scripts
- Use **bash** for all shell scripts
- Follow the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Use `set -euo pipefail` at the beginning of scripts
- Include comprehensive error handling
- Add comments for complex logic
- Use descriptive variable names

#### Dockerfile
- Follow [Dockerfile best practices](https://docs.docker.com/develop/dev-best-practices/)
- Use multi-stage builds when appropriate
- Minimize the number of layers
- Use specific version tags for base images
- Run containers as non-root user
- Include security scanning in CI/CD

#### Documentation
- Use clear, concise language
- Include examples for all features
- Keep README.md up to date
- Document breaking changes
- Include security considerations

### Testing Requirements

All contributions must include appropriate tests:

#### Unit Tests
```bash
# Test individual functions
./scripts/test-validation.sh
./scripts/test-backup.sh
```

#### Integration Tests
```bash
# Test with real EKS clusters (requires AWS credentials)
./scripts/test-integration.sh
```

#### Security Tests
```bash
# Run security scans
./scripts/security-scan.sh
```

### Pre-commit Checks

Before submitting a pull request, run these checks:

```bash
# Lint shell scripts
find . -name "*.sh" -type f -exec shellcheck {} \;

# Lint Dockerfile
hadolint Dockerfile

# Security scan
trivy fs .

# Test the action
docker run --rm \
  -e INPUT_CLUSTER_NAME=test \
  -e INPUT_REGION=us-west-2 \
  -e INPUT_HELM_COMMANDS="helm version" \
  eks-helm-client:dev
```

## 📝 Contribution Process

### 1. Issue Creation

Before starting work:

- **Check existing issues** to avoid duplication
- **Create a new issue** describing:
  - The problem or feature request
  - Expected behavior
  - Current behavior (for bugs)
  - Steps to reproduce (for bugs)
  - Your environment details

### 2. Branch Naming

Use descriptive branch names:

- **Features**: `feature/add-secrets-manager-support`
- **Bug fixes**: `fix/private-cluster-connection`
- **Documentation**: `docs/update-security-guide`
- **Chores**: `chore/update-dependencies`

### 3. Development Workflow

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**:
   - Write code following our style guidelines
   - Add tests for new functionality
   - Update documentation as needed

3. **Test your changes**:
   ```bash
   # Build and test
   docker build -t eks-helm-client:test .
   ./scripts/test-scenarios.sh
   
   # Security scan
   ./scripts/security-scan.sh
   ```

4. **Commit your changes**:
   ```bash
   git add .
   git commit -m "feat: add AWS Secrets Manager support"
   ```

### 4. Commit Message Guidelines

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- **feat**: New features
- **fix**: Bug fixes
- **docs**: Documentation changes
- **style**: Code style changes (formatting, etc.)
- **refactor**: Code refactoring
- **test**: Adding or updating tests
- **chore**: Build process or auxiliary tool changes

Examples:
```
feat: add support for private EKS clusters
fix: resolve timeout issues in Helm deployment
docs: update README with new security features
test: add integration tests for backup functionality
```

### 5. Pull Request Process

1. **Push your branch**:
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create a pull request** with:
   - **Clear title** describing the change
   - **Detailed description** including:
     - What changed
     - Why it changed
     - How to test it
     - Any breaking changes
   - **Link to related issues**
   - **Screenshots** (if applicable)

3. **PR Checklist**:
   - [ ] Tests pass
   - [ ] Documentation updated
   - [ ] Security scan clean
   - [ ] Backward compatibility maintained (or breaking change documented)
   - [ ] CHANGELOG.md updated (for significant changes)

## 🔒 Security Considerations

### Reporting Security Issues

**DO NOT** create public issues for security vulnerabilities. Instead:

1. Email: [dinushchathurya21@gmail.com](mailto:dinushchathurya21@gmail.com)
2. Include detailed information about the vulnerability
3. Allow time for assessment and fix before public disclosure

### Security Development Practices

- **Never commit secrets** or credentials
- **Use environment variables** for sensitive configuration
- **Validate all inputs** to prevent injection attacks
- **Follow least privilege principle** in IAM policies
- **Regular security scanning** of dependencies and container images

## 🧪 Testing Guide

### Local Testing

1. **Basic functionality test**:
   ```bash
   docker run --rm \
     -e INPUT_CLUSTER_NAME=your-test-cluster \
     -e INPUT_REGION=us-west-2 \
     -e INPUT_HELM_COMMANDS="helm version" \
     -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
     -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
     eks-helm-client:test
   ```

2. **Private cluster test**:
   ```bash
   docker run --rm \
     -e INPUT_CLUSTER_NAME=private-cluster \
     -e INPUT_REGION=us-west-2 \
     -e INPUT_PRIVATE_CLUSTER=true \
     -e INPUT_HELM_COMMANDS="helm version" \
     eks-helm-client:test
   ```

3. **Security features test**:
   ```bash
   docker run --rm \
     -e INPUT_CLUSTER_NAME=test-cluster \
     -e INPUT_REGION=us-west-2 \
     -e INPUT_VERIFY_CHARTS=true \
     -e INPUT_VALIDATE_MANIFESTS=true \
     -e INPUT_HELM_COMMANDS="helm version" \
     eks-helm-client:test
   ```

### Integration Testing

For integration tests with real AWS resources:

1. **Set up test EKS cluster**
2. **Configure IAM roles** with minimal permissions
3. **Run comprehensive test suite**:
   ```bash
   export TEST_CLUSTER_NAME=eks-test-cluster
   export TEST_REGION=us-west-2
   ./scripts/integration-tests.sh
   ```

## 📚 Documentation Standards

### Code Documentation

- **Comment complex logic** in shell scripts
- **Document environment variables** and their purposes
- **Include usage examples** for new features
- **Document security implications** of changes

### User Documentation

- **Update README.md** for new features
- **Add examples** showing how to use new functionality
- **Document breaking changes** in migration guides
- **Include troubleshooting** for common issues

## 🔄 Release Process

### Version Management

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Checklist

- [ ] All tests pass
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Security scan clean
- [ ] Version tags updated
- [ ] Release notes prepared

## 🤝 Community Guidelines

### Code of Conduct

This project adheres to our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

### Communication

- **Be respectful** and constructive in discussions
- **Provide clear context** when asking for help
- **Help others** when you can
- **Share knowledge** and best practices

### Recognition

Contributors will be recognized in:

- **CONTRIBUTORS.md** file
- **Release notes** for significant contributions
- **GitHub contributors** section

## 📞 Getting Help

If you need help with development:

1. **Check existing documentation** and issues
2. **Create a discussion** on GitHub for questions
3. **Join our community** channels (if available)
4. **Email maintainers** for complex questions

## 📋 Quick Reference

### Useful Commands

```bash
# Build image
docker build -t eks-helm-client:dev .

# Run tests
./scripts/test-scenarios.sh

# Security scan
./scripts/security-scan.sh

# Lint shell scripts
shellcheck scripts/*.sh entrypoint.sh

# Lint Dockerfile
hadolint Dockerfile

# Clean up
./scripts/cleanup.sh
```

### Directory Structure

```
├── Dockerfile              # Container definition
├── action.yml             # GitHub Action metadata
├── entrypoint.sh          # Main entry point
├── config.template        # Kubeconfig template
├── scripts/               # Helper scripts
│   ├── validate-cluster.sh
│   ├── backup-releases.sh
│   ├── validate-manifests.sh
│   ├── security-scan.sh
│   ├── test-scenarios.sh
│   ├── cleanup.sh
│   └── setup-development.sh
├── docs/                  # Additional documentation
├── examples/              # Usage examples
└── tests/                 # Test files
```

Thank you for contributing to the EKS Helm Client GitHub Action! Your contributions help make this tool better for everyone. 🚀