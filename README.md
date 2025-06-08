# GitHub Action to deploy Helm Charts in EKS

[![GitHub release](https://img.shields.io/github/release/open-source-srilanka/eks-helm-client-github-action.svg)](https://github.com/open-source-srilanka/eks-helm-client-github-action/releases)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE.md)
[![Security](https://img.shields.io/badge/Security-Scanned-green.svg)](docs/SECURITY.md)

This GitHub Action allows you to install and upgrade Helm Charts in Amazon EKS clusters, including **private EKS clusters** and **private Helm repositories**. Version 2.0.0 introduces comprehensive support for enterprise-grade private infrastructure with enhanced security and reliability features.

## ✨ Features

- 🔒 **Private EKS Cluster Support** - Full support for private EKS clusters with proper network connectivity validation
- 🏢 **Private Helm Repository Support** - Authenticate and deploy from private Helm registries
- 🛡️ **Enhanced Security** - Improved authentication mechanisms and credential handling
- ⚡ **Configurable Versions** - Choose specific kubectl and Helm versions
- 🐛 **Debug Mode** - Comprehensive logging and troubleshooting capabilities
- ⏱️ **Timeout Control** - Configurable timeouts for operations
- 🧪 **Dry Run Mode** - Test configurations without making actual changes
- 🏥 **Health Checks** - Built-in container health verification

## 🚀 Quick Start

### Basic Usage (Public EKS)

```yaml
steps:
  - name: Setup AWS Credentials
    uses: aws-actions/configure-aws-credentials@v4
    with:
      aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
      aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      aws-region: us-west-2

  - name: Deploy to EKS
    uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
    with:
      cluster-name: my-eks-cluster
      region: us-west-2
      args: |
        helm repo add bitnami https://charts.bitnami.com/bitnami
        helm repo update
        helm upgrade --install my-app bitnami/nginx --namespace default
```

### Private EKS Cluster

```yaml
steps:
  - name: Setup AWS Credentials
    uses: aws-actions/configure-aws-credentials@v4
    with:
      aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
      aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      aws-region: us-west-2

  - name: Deploy to Private EKS
    uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
    with:
      cluster-name: my-private-eks
      region: us-west-2
      private-cluster: true
      timeout: 600
      debug: true
      args: |
        helm upgrade --install my-app ./charts/my-app --namespace production --create-namespace
```

### Private Helm Repository

```yaml
steps:
  - name: Setup AWS Credentials
    uses: aws-actions/configure-aws-credentials@v4
    with:
      aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
      aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      aws-region: us-west-2

  - name: Deploy from Private Registry
    uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
    with:
      cluster-name: my-eks-cluster
      region: us-west-2
      helm-registry-url: https://my-company-helm-registry.com/charts
      helm-registry-username: ${{ secrets.HELM_REGISTRY_USERNAME }}
      helm-registry-password: ${{ secrets.HELM_REGISTRY_PASSWORD }}
      args: |
        helm repo update
        helm upgrade --install my-private-app private-registry/my-app --namespace production
```

## 📋 Inputs

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `args` | Commands to execute for Helm operations | ✅ | - |
| `cluster-name` | EKS cluster name | ❌ | From env `CLUSTER_NAME` |
| `region` | AWS region where EKS cluster is located | ❌ | From env `REGION_CODE` |
| `private-cluster` | Set to `true` for private EKS clusters | ❌ | `false` |
| `helm-registry-url` | Private Helm registry URL | ❌ | - |
| `helm-registry-username` | Username for private Helm registry | ❌ | - |
| `helm-registry-password` | Password for private Helm registry | ❌ | - |
| `helm-registry-insecure` | Allow insecure registry connections | ❌ | `false` |
| `kubectl-version` | Specific kubectl version to use | ❌ | `1.28.4` |
| `helm-version` | Specific Helm version to use | ❌ | `3.13.3` |
| `timeout` | Operation timeout in seconds | ❌ | `300` |
| `debug` | Enable debug logging | ❌ | `false` |
| `kubeconfig-path` | Custom kubeconfig file path | ❌ | `/opt/kubernetes/config` |
| `dry-run` | Show commands without executing | ❌ | `false` |

## 🔐 Private EKS Clusters

When working with private EKS clusters, ensure your GitHub runner environment meets these requirements:

### Network Requirements

1. **Self-hosted Runners**: Deploy runners in the same VPC as your private EKS cluster
2. **VPC Endpoints**: Configure VPC endpoints for AWS services if needed:
   - `com.amazonaws.region.eks`
   - `com.amazonaws.region.sts`
   - `com.amazonaws.region.s3` (if using S3-based Helm repos)

3. **Security Groups**: Ensure runners can reach:
   - EKS API endpoint (port 443)
   - Private Helm registries (typically port 443)

### Example with VPC Configuration

```yaml
# For self-hosted runners in private subnets
steps:
  - name: Deploy to Private EKS
    uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
    with:
      cluster-name: ${{ secrets.PRIVATE_EKS_CLUSTER }}
      region: us-west-2
      private-cluster: true
      timeout: 900  # Increased timeout for private networks
      debug: true   # Enable for troubleshooting
      args: |
        # Verify connectivity first
        kubectl cluster-info
        helm list --all-namespaces
        
        # Deploy application
        helm upgrade --install my-app ./charts/my-app \
          --namespace production \
          --create-namespace \
          --wait \
          --timeout 10m
```

## 🏢 Private Helm Registries

### Supported Registry Types

- **Harbor**: Private container and Helm registry
- **Nexus Repository**: Sonatype Nexus with Helm support
- **Artifactory**: JFrog Artifactory with Helm repositories
- **AWS ECR**: Amazon Elastic Container Registry (OCI format)
- **Azure Container Registry**: Microsoft ACR with Helm support
- **Custom Registries**: Any Helm-compatible private registry

### Authentication Examples

#### Basic Authentication
```yaml
with:
  helm-registry-url: https://harbor.company.com/chartrepo/project
  helm-registry-username: ${{ secrets.HARBOR_USERNAME }}
  helm-registry-password: ${{ secrets.HARBOR_PASSWORD }}
```

#### AWS ECR (OCI Format)
```yaml
steps:
  - name: Login to Amazon ECR
    uses: aws-actions/amazon-ecr-login@v1

  - name: Deploy from ECR
    uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
    with:
      cluster-name: my-cluster
      region: us-west-2
      args: |
        helm upgrade --install my-app oci://123456789012.dkr.ecr.us-west-2.amazonaws.com/my-charts/my-app \
          --version 1.0.0 \
          --namespace production
```

## 🛠️ Advanced Usage

### Multiple Helm Repositories

```yaml
with:
  args: |
    # Add multiple repositories
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add stable https://charts.helm.sh/stable
    helm repo add private-registry https://registry.company.com/helm --username $HELM_USER --password $HELM_PASS
    
    # Update all repositories
    helm repo update
    
    # Deploy from different repos
    helm upgrade --install redis bitnami/redis --namespace cache --create-namespace
    helm upgrade --install app private-registry/my-app --namespace production --create-namespace
```

### Helm Values and Configurations

```yaml
with:
  args: |
    # Deploy with custom values
    helm upgrade --install my-app bitnami/nginx \
      --namespace production \
      --create-namespace \
      --values values.yaml \
      --set replicaCount=3 \
      --set image.tag=latest \
      --wait \
      --timeout 10m
    
    # Verify deployment
    kubectl get pods -n production
    helm status my-app -n production
```

### Debug and Troubleshooting

```yaml
with:
  debug: true
  timeout: 900
  args: |
    # Enable Helm debug mode
    export HELM_DEBUG=true
    
    # Check cluster connectivity
    kubectl cluster-info dump --output-directory=/tmp/cluster-info
    
    # List existing releases
    helm list --all-namespaces
    
    # Deploy with verbose output
    helm upgrade --install my-app ./charts/my-app \
      --namespace production \
      --create-namespace \
      --debug \
      --dry-run
```

## 🧪 Testing and Validation

### Dry Run Mode

```yaml
with:
  dry-run: true
  args: |
    helm upgrade --install my-app bitnami/nginx --namespace test --dry-run
```

### Connectivity Testing

```yaml
with:
  debug: true
  args: |
    # Test cluster access
    kubectl auth can-i '*' '*' --all-namespaces
    
    # Test Helm functionality
    helm version
    helm repo list
    
    # Validate charts
    helm lint ./charts/my-app
    helm template my-app ./charts/my-app --validate
```

## 🔧 Troubleshooting

### Common Issues

**Private EKS Connection Failed**
```bash
# Enable debug mode to see detailed logs
debug: true

# Check if runner can reach EKS endpoint
# Ensure security groups allow port 443 access
# Verify VPC endpoints are configured correctly
```

**Private Registry Authentication Failed**
```bash
# Verify credentials are correct
# Test registry connectivity from runner
# Check if registry supports Helm protocol version
```

**Timeout Issues**
```bash
# Increase timeout for private networks
timeout: 900

# Use --wait flag with Helm commands
helm upgrade --install my-app chart --wait --timeout 15m
```

### Debug Checklist

1. ✅ AWS credentials configured correctly
2. ✅ Runner has network access to EKS API
3. ✅ Security groups allow required ports
4. ✅ Helm registry credentials are valid
5. ✅ kubectl can connect to cluster
6. ✅ Helm can list repositories and charts

## 📚 Migration from v1.0.0

### Backward Compatibility

Your existing v1.0.0 workflows will continue to work unchanged:

```yaml
# v1.0.0 style - still works in v2.0.0
env:
  CLUSTER_NAME: my-cluster
  REGION_CODE: us-west-2
with:
  args: "helm install my-app bitnami/nginx"
```

### New v2.0.0 Style

Take advantage of new features with input parameters:

```yaml
# v2.0.0 style - recommended for new workflows
with:
  cluster-name: my-cluster
  region: us-west-2
  private-cluster: true
  helm-registry-url: https://harbor.company.com
  args: "helm install my-app private-registry/my-app"
```

See the complete [Migration Guide](docs/MIGRATION.md) for detailed upgrade instructions.

## 📚 Examples Repository

Find comprehensive examples and use cases in our documentation:

- [Basic Usage Examples](docs/examples/basic-usage.md)
- [Private Cluster Examples](docs/examples/private-cluster.md)
- [Private Registry Examples](docs/examples/private-registry.md)
- [Advanced Scenarios](docs/examples/advanced-scenarios.md)
- [Troubleshooting Guide](docs/examples/troubleshooting.md)

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](docs/CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md).

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.

## 🆕 Changelog

### v2.0.0 (Latest)
- ✨ Added private EKS cluster support
- ✨ Added private Helm repository authentication
- ✨ Enhanced debugging and logging capabilities
- ✨ Configurable kubectl and Helm versions
- ✨ Improved error handling and connectivity testing
- ✨ Added health checks and container validation
- ✨ Dry run mode for testing configurations
- 🔧 Breaking: Some input parameter names changed for consistency

### v1.0.0 (Legacy)
- ✅ Basic EKS and Helm functionality
- ✅ Public cluster support only

## 📞 Support

For questions, issues, or feature requests:

- 📧 Email: [dinushchathurya21@gmail.com](mailto:dinushchathurya21@gmail.com)
- 🐛 Issues: [GitHub Issues](https://github.com/open-source-srilanka/eks-helm-client-github-action/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/open-source-srilanka/eks-helm-client-github-action/discussions)

## 📤 Author

**Made with ❤️ & ☕ by <a href="https://dinushchathurya.me/"><u style="color:#0193f0;">Dinush Chathurya</u></a> as a part of <a href="https://github.com/open-source-srilanka"><u style="color:#0193f0;">ProjectOSS</u></a>** 



