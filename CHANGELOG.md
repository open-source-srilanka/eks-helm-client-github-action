# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2025-06-05

### 🎉 Major Release - Private Infrastructure Support

This is a major release that adds comprehensive support for private EKS clusters and private Helm repositories, making this action enterprise-ready.

### ✨ Added

#### Private Infrastructure Support
- **Private EKS Cluster Support** - Full support for EKS clusters without public endpoints
- **Private Helm Repository Authentication** - Support for Harbor, Nexus, Artifactory, ECR, and custom registries
- **Network Connectivity Validation** - Automatic testing of cluster and registry connectivity
- **Enhanced Security Features** - Improved credential handling and cleanup

#### New Input Parameters
- `cluster-name` - EKS cluster name (replaces environment variable)
- `region` - AWS region (replaces environment variable)
- `private-cluster` - Enable private cluster mode
- `helm-registry-url` - Private Helm registry URL
- `helm-registry-username` - Registry authentication username
- `helm-registry-password` - Registry authentication password
- `helm-registry-insecure` - Allow insecure registry connections
- `kubectl-version` - Configurable kubectl version
- `helm-version` - Configurable Helm version
- `timeout` - Configurable operation timeouts
- `debug` - Enhanced debug logging
- `kubeconfig-path` - Custom kubeconfig location
- `dry-run` - Test mode without executing commands

#### Enhanced Features
- **Health Checks** - Container health validation
- **Debug Mode** - Comprehensive logging and troubleshooting
- **Timeout Controls** - Configurable timeouts for all operations
- **Version Flexibility** - Choose specific tool versions
- **Error Handling** - Improved error messages and recovery

#### Documentation & Testing
- **Migration Guide** - Complete v1 to v2 migration documentation
- **Comprehensive Examples** - Usage examples for all scenarios
- **Test Suite** - Automated testing for public/private infrastructure
- **Troubleshooting Guide** - Common issues and solutions

### 🔧 Changed

#### Breaking Changes
- **Input Parameters** - Environment variables `REGION_CODE` and `CLUSTER_NAME` can now be replaced with input parameters
- **Container Base Image** - Updated to Alpine 3.18 for better security
- **Tool Versions** - Updated default kubectl to 1.28.4 and Helm to 3.13.3

#### Improvements
- **Enhanced Logging** - Better formatted output with color coding
- **Improved Performance** - Faster startup and reduced container size
- **Better Security** - Automatic credential cleanup and validation
- **Network Validation** - Pre-flight connectivity checks

### 🐛 Fixed
- **Timeout Handling** - Better timeout management for slow networks
- **Error Recovery** - Improved error handling and cleanup
- **Memory Usage** - Optimized container resource usage
- **Network Issues** - Better handling of network connectivity problems

### 🔒 Security
- **Credential Cleanup** - Automatic removal of sensitive data
- **Registry Authentication** - Secure handling of private registry credentials
- **Network Security** - Validation of SSL/TLS connections
- **Container Security** - Updated base image and security patches

### 📚 Documentation
- **Complete Rewrite** - Comprehensive documentation with examples
- **Migration Guide** - Step-by-step v1 to v2 migration
- **Troubleshooting** - Common issues and solutions
- **Best Practices** - Recommended usage patterns

### 🧪 Testing
- **Automated Tests** - Comprehensive test suite for all features
- **Integration Tests** - End-to-end testing with real clusters
- **Security Tests** - Validation of security features
- **Performance Tests** - Startup and operation performance validation

---

## [1.0.0] - 2023-10-15

### ✨ Initial Release

#### Added
- **Basic EKS Support** - Deploy Helm charts to public EKS clusters
- **AWS Authentication** - IAM-based authentication for EKS access
- **Helm Operations** - Install, upgrade, and manage Helm releases
- **Simple Configuration** - Environment variable-based configuration

#### Features
- Public EKS cluster support
- Basic Helm chart deployment
- AWS IAM authentication
- Simple command execution

#### Tools Included
- kubectl v1.27.1
- Helm v3.12.3
- AWS CLI
- AWS IAM Authenticator v0.6.11

---

## Migration Notes

### From v1.0.0 to v2.0.0

**⚠️ Breaking Changes:**
- Input parameters now preferred over environment variables
- Some tool versions updated by default

**🔄 Migration Steps:**
1. Update action version to `@v2.0.0`
2. Convert environment variables to input parameters
3. Add private infrastructure parameters if needed
4. Test with dry-run mode
5. Update documentation and workflows

**📖 Resources:**
- [Migration Guide](docs/MIGRATION.md)
- [Examples](docs/examples/)
- [Troubleshooting](docs/examples/troubleshooting.md)

---

## Support

- 📧 **Email**: [dinushchathurya21@gmail.com](mailto:dinushchathurya21@gmail.com)
- 🐛 **Issues**: [GitHub Issues](https://github.com/open-source-srilanka/eks-helm-client-github-action/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/open-source-srilanka/eks-helm-client-github-action/discussions)

---

**Made with ❤️ & ☕ by <a href="https://dinushchathurya.me/"><u style="color:#0193f0;">Dinush Chathurya</u></a> as a part of <a href="https://github.com/open-source-srilanka"><u style="color:#0193f0;">ProjectOSS</u></a>**
