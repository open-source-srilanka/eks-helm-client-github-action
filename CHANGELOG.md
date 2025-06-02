# Changelog

All notable changes to the EKS Helm Client GitHub Action will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive documentation and examples for private registry usage
- Security scanning and best practices for private charts
- Integration test framework for multiple registry types

## [2.0.0] - 2025-06-02

### Added
- **🔒 Comprehensive Private Helm Package Support**
  - **AWS ECR integration** with automatic authentication
  - **GitHub Container Registry** support with GITHUB_TOKEN
  - **Private Helm repositories** with secure credential management
  - **Multiple registry support** in a single deployment
  - **Cross-account ECR access** with role assumption
- **Private EKS cluster support** with VPC endpoints and bastion host configuration
- **Enhanced security features** including IRSA support and chart verification
- **AWS Secrets Manager integration** for secure secret and credential handling
- **Manifest validation** before deployment
- **Atomic deployments** with automatic rollback capabilities
- **Backup functionality** to S3 before deployments
- **Dry-run mode** for testing deployments
- **Multi-namespace support** with automatic namespace creation
- **Enhanced logging** with color-coded output and debug mode
- **Non-root container execution** for improved security
- **Comprehensive input validation** and error handling
- **Modern tool versions**: kubectl 1.30.0, Helm 3.14.4, Alpine 3.19
- **Kubeseal support** for sealed secrets
- **Helper functions** for OCI and private repository operations

### Private Registry Features
- `auto-login-ecr`: Automatic AWS ECR authentication
- `ecr-registry`: Specify custom ECR registry URL
- `github-packages-token`: GitHub Container Registry authentication
- `private-registry-url`: Primary private registry URL
- `private-registry-username/password`: Direct credential input
- `private-registry-username/password-secret`: AWS Secrets Manager integration
- `additional-registries`: JSON configuration for multiple registries
- Registry credential isolation and secure cleanup
- OCI registry support with modern authentication
- Chart signature verification for private charts

### Changed
- **BREAKING**: Renamed `args` parameter to `helm-commands` for clarity
- **BREAKING**: Environment variables now use `INPUT_` prefix
- **BREAKING**: Removed deprecated aws-iam-authenticator in favor of native AWS CLI
- Updated base image from Alpine 3.14 to Alpine 3.19
- Updated kubectl from 1.27.1 to 1.30.0
- Updated Helm from 3.12.3 to 3.14.4
- Improved error handling and logging throughout
- Enhanced kubeconfig template with modern authentication
- Registry authentication now supports multiple concurrent registries

### Security
- Added checksum verification for all downloaded binaries
- Implemented non-root user execution (UID 1001)
- Added comprehensive security scanning in CI/CD
- Enhanced IAM role assumption with session management
- Improved temporary file cleanup and secret handling
- **Private registry credential security**:
  - Credentials never logged or exposed
  - Automatic credential cleanup after use
  - Isolated authentication per registry
  - Secure storage integration with AWS Secrets Manager
- **Registry access security**:
  - TLS verification for all registry connections
  - Support for private CA certificates
  - Comprehensive audit logging of registry operations

### Deprecated
- Legacy environment variable names (use INPUT_ prefix instead)
- Direct aws-iam-authenticator usage (use AWS CLI native auth)

### Removed
- Support for very old kubectl versions (< 1.28)
- Legacy authentication methods
- Deprecated Helm 2 compatibility code

### Fixed
- Connection issues with private EKS clusters
- Timeout handling in Helm operations
- Permission issues with temporary directories
- Race conditions in concurrent deployments
- **Private registry authentication issues**:
  - Fixed credential caching conflicts between registries
  - Resolved authentication timeout issues with slow registries
  - Fixed OCI registry authentication with special characters in credentials
  - Resolved cross-account ECR authentication edge cases

### Private Registry Support Details

#### AWS ECR
- Automatic authentication using AWS CLI and IRSA
- Support for cross-account ECR registries
- Custom ECR registry URL specification
- Integration with VPC endpoints for private clusters
- Comprehensive error handling for ECR authentication failures

#### GitHub Container Registry
- Native integration with GitHub Actions tokens
- Support for organization and personal packages
- Automatic cleanup of authentication credentials
- Compatible with fine-grained personal access tokens

#### Private Helm Repositories
- Support for traditional Helm repositories with authentication
- Integration with popular registry solutions (Harbor, Artifactory, Nexus)
- Flexible authentication methods (basic auth, token-based)
- Secure credential management through AWS Secrets Manager

#### Multi-Registry Deployments
- Support for deploying from multiple private registries in a single workflow
- Automatic credential isolation between registries
- JSON-based configuration for additional registries
- Comprehensive error handling and logging per registry

## [1.0.0] - 2023-XX-XX

### Added
- Initial release of EKS Helm Client GitHub Action
- Basic Helm chart deployment to EKS clusters
- AWS authentication support
- Simple error handling and logging

### Features
- Deploy Helm charts to public EKS clusters
- Basic AWS credential support
- Simple args-based command execution
- Alpine Linux based container

---

## Migration Guide

### Migrating from v1.x to v2.0

#### Required Changes

1. **Update action version**:
   ```diff
   - uses: open-source-srilanka/eks-helm-client-github-action@v1.0.0
   + uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
   ```

2. **Update parameter names**:
   ```diff
   with:
   -   args: "helm install my-app ./chart"
   +   helm-commands: "helm install my-app ./chart"
   +   cluster-name: my-cluster
   +   region: us-west-2
   ```

3. **Remove environment variables** (now passed as inputs):
   ```diff
   - env:
   -   REGION_CODE: us-west-2
   -   CLUSTER_NAME: my-cluster
   ```

#### Private Registry Migration

4. **Enable private registry support**:
   ```yaml
   # For AWS ECR
   with:
     auto-login-ecr: true
   
   # For GitHub Packages
   with:
     github-packages-token: ${{ secrets.GITHUB_TOKEN }}
   
   # For private repositories
   with:
     private-registry-url: https://charts.company.com
     private-registry-username-secret: helm/repo/username
     private-registry-password-secret: helm/repo/password
   ```

#### Recommended Changes

1. **Upgrade to IRSA authentication**:
   ```yaml
   - name: Configure AWS Credentials
     uses: aws-actions/configure-aws-credentials@v4
     with:
       role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
       role-session-name: github-actions-deployment
       aws-region: us-west-2
   ```

2. **Enable security features**:
   ```yaml
   with:
     verify-charts: true
     validate-manifests: true
     atomic: true
     wait: true
   ```

3. **Use namespace management**:
   ```yaml
   with:
     namespace: production
     create-namespace: true
   ```

#### Private Registry Examples

**ECR Migration**:
```yaml
# Before (manual)
helm-commands: |
  aws ecr get-login-password | helm registry login --username AWS --password-stdin 123456789012.dkr.ecr.us-west-2.amazonaws.com
  helm upgrade --install my-app oci://123456789012.dkr.ecr.us-west-2.amazonaws.com/charts/my-app

# After (automatic)
with:
  auto-login-ecr: true
  helm-commands: |
    helm upgrade --install my-app oci://123456789012.dkr.ecr.us-west-2.amazonaws.com/charts/my-app
```

**GitHub Packages Migration**:
```yaml
# Before (manual)
helm-commands: |
  echo ${{ secrets.GITHUB_TOKEN }} | helm registry login --username ${{ github.actor }} --password-stdin ghcr.io
  helm upgrade --install my-app oci://ghcr.io/my-org/my-chart

# After (automatic)
with:
  github-packages-token: ${{ secrets.GITHUB_TOKEN }}
  helm-commands: |
    helm upgrade --install my-app oci://ghcr.io/my-org/my-chart
```

#### Breaking Changes Details

| v1.x | v2.0 | Notes |
|------|------|-------|
| `args` | `helm-commands` | Parameter renamed for clarity |
| `REGION_CODE` env | `region` input | Environment variable moved to input |
| `CLUSTER_NAME` env | `cluster-name` input | Environment variable moved to input |
| aws-iam-authenticator | AWS CLI native | Authentication method modernized |
| Manual registry auth | Automatic registry auth | Private registry authentication automated |

---

## Private Registry Security Considerations

### ECR Security Updates
- Enhanced IRSA integration for ECR authentication
- Improved cross-account access patterns
- Better error handling for ECR authentication failures
- VPC endpoint support for private ECR access

### General Registry Security
- Credential isolation between registries
- Automatic credential cleanup
- Enhanced audit logging
- TLS verification enforcement

## Support

For questions about changes, migration, or private registry setup:

- **Documentation**: [README.md](README.md)
- **Private Registry Examples**: [examples/private-helm-examples.yml](examples/private-helm-examples.yml)
- **Security Guide**: [SECURITY.md](SECURITY.md)
- **Issues**: [GitHub Issues](https://github.com/open-source-srilanka/eks-helm-client-github-action/issues)
- **Discussions**: [GitHub Discussions](https://github.com/open-source-srilanka/eks-helm-client-github-action/discussions)
- **Email**: [dinushchathurya21@gmail.com](mailto:dinushchathurya21@gmail.com)

