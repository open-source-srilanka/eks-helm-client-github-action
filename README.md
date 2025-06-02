# GitHub Action for Secure EKS Helm Deployments

This enhanced GitHub Action allows you to securely install and upgrade Helm Charts on both public and private Amazon EKS clusters. It includes modern security practices, private cluster support, **comprehensive private Helm package support**, and advanced validation features.

## 🆕 What's New in v2.0

- **Private EKS Cluster Support**: Full support for private clusters with VPC endpoints and bastion hosts
- **🔒 Private Helm Package Support**: AWS ECR, GitHub Packages, private repositories, and multi-registry support
- **Enhanced Security**: IAM Roles for Service Accounts (IRSA), chart verification, and minimal attack surface
- **Modern Tool Versions**: Latest kubectl, Helm, and AWS CLI versions
- **Advanced Features**: Manifest validation, backup capabilities, secrets management integration
- **Better Error Handling**: Comprehensive logging, rollback capabilities, and detailed error messages
- **Multi-Environment Support**: Environment-specific configurations and validation

## 🔧 Features

### Core Capabilities
- ✅ Deploy to public and private EKS clusters
- ✅ Support for Helm 3.14+ with OCI chart support
- ✅ Kubernetes 1.30+ compatibility
- ✅ Atomic deployments with automatic rollback
- ✅ Multi-namespace deployments

### 🔒 Private Helm Package Support
- ✅ **AWS ECR** - Automatic authentication and OCI support
- ✅ **GitHub Container Registry** - GitHub Packages integration
- ✅ **Private Helm Repositories** - Traditional repositories with authentication
- ✅ **Multiple Registries** - Support for multiple private sources in one deployment
- ✅ **Secrets Manager Integration** - Secure credential management

### Security Features
- 🔒 IAM Roles for Service Accounts (IRSA) support
- 🔒 Chart signature verification
- 🔒 AWS Secrets Manager integration
- 🔒 Non-root container execution
- 🔒 Minimal Alpine-based image with security updates

### Private Cluster Support
- 🏠 VPC endpoint configuration
- 🏠 Bastion host access support
- 🏠 Private subnet connectivity
- 🏠 Custom CA certificate handling

### Advanced Operations
- 📊 Pre-deployment validation
- 💾 Automated backup capabilities
- 🔄 Deployment status tracking
- 🐛 Debug mode with detailed logging
- 🧪 Dry-run capabilities

## 🚀 Quick Start

### Basic Usage (Public Cluster)

```yaml
name: Deploy to EKS
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          role-session-name: github-actions-deployment
          aws-region: us-west-2

      - name: Deploy Helm Chart
        uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
        with:
          cluster-name: my-production-cluster
          region: us-west-2
          namespace: production
          create-namespace: true
          helm-commands: |
            helm repo add bitnami https://charts.bitnami.com/bitnami
            helm repo update
            helm upgrade --install my-app bitnami/nginx \
              --set service.type=LoadBalancer \
              --set ingress.enabled=true
```

## 🔒 Private Helm Package Examples

### AWS ECR (Recommended for AWS environments)

#### Simple ECR Deployment
```yaml
- name: Deploy from AWS ECR
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: production-cluster
    region: us-west-2
    auto-login-ecr: true
    helm-commands: |
      helm upgrade --install my-app \
        oci://123456789012.dkr.ecr.us-west-2.amazonaws.com/charts/my-private-app \
        --version 1.2.3
```

#### ECR with Cross-Account Access
```yaml
- name: Deploy from Cross-Account ECR
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: production-cluster
    region: us-west-2
    role-arn: arn:aws:iam::987654321098:role/CrossAccountECRAccess
    ecr-registry: 987654321098.dkr.ecr.us-west-2.amazonaws.com
    helm-commands: |
      helm upgrade --install shared-service \
        oci://987654321098.dkr.ecr.us-west-2.amazonaws.com/shared/charts/common-service \
        --version 2.1.0
```

### GitHub Container Registry

```yaml
- name: Deploy from GitHub Packages
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: production-cluster
    region: us-west-2
    github-packages-token: ${{ secrets.GITHUB_TOKEN }}
    helm-commands: |
      helm upgrade --install my-app \
        oci://ghcr.io/my-org/my-private-chart \
        --version 1.0.0 \
        --set image.tag=${{ github.sha }}
```

### Private Helm Repository (Traditional)

#### With Direct Credentials
```yaml
- name: Deploy from Private Repository
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: production-cluster
    region: us-west-2
    private-registry-url: https://charts.company.com
    private-registry-username: ${{ secrets.HELM_REPO_USERNAME }}
    private-registry-password: ${{ secrets.HELM_REPO_PASSWORD }}
    helm-commands: |
      helm repo add company-charts https://charts.company.com \
        --username "${PRIVATE_REGISTRY_USERNAME}" \
        --password "${PRIVATE_REGISTRY_PASSWORD}"
      helm repo update
      helm upgrade --install my-app company-charts/private-application \
        --version 3.2.1
```

#### With AWS Secrets Manager
```yaml
- name: Deploy with Secrets Manager
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: production-cluster
    region: us-west-2
    enable-secrets-manager: true
    private-registry-url: https://charts.company.com
    private-registry-username-secret: helm/repo/username
    private-registry-password-secret: helm/repo/password
    helm-commands: |
      helm repo add company-charts https://charts.company.com
      helm repo update
      helm upgrade --install my-app company-charts/private-app \
        --set-string database.password="$(aws-secret prod/db-password)"
```

### Multiple Private Registries

```yaml
- name: Deploy from Multiple Private Sources
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: production-cluster
    region: us-west-2
    auto-login-ecr: true
    github-packages-token: ${{ secrets.GITHUB_TOKEN }}
    additional-registries: |
      [
        {
          "url": "registry.company.com",
          "username": "${{ secrets.PRIVATE_REG_USER }}",
          "password": "${{ secrets.PRIVATE_REG_PASS }}"
        },
        {
          "url": "harbor.internal.com",
          "username": "${{ secrets.HARBOR_USER }}",
          "password": "${{ secrets.HARBOR_PASS }}"
        }
      ]
    helm-commands: |
      # Deploy from AWS ECR
      helm upgrade --install database \
        oci://123456789012.dkr.ecr.us-west-2.amazonaws.com/charts/postgresql \
        --version 12.1.0
      
      # Deploy from GitHub Packages
      helm upgrade --install frontend \
        oci://ghcr.io/my-org/frontend-chart \
        --version 2.0.0
      
      # Deploy from additional private registries
      helm repo add company https://registry.company.com/charts
      helm repo add harbor https://harbor.internal.com/chartrepo/library
      helm repo update
      
      helm upgrade --install backend company/backend-service --version 1.5.0
      helm upgrade --install monitoring harbor/prometheus-stack --version 15.0.0
```

### Private Cluster with Private Charts

```yaml
- name: Deploy to Private EKS with Private Charts
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: private-production-cluster
    region: us-west-2
    private-cluster: true
    vpc-endpoint: https://vpce-12345.eks.us-west-2.vpce.amazonaws.com
    
    # Private chart authentication
    auto-login-ecr: true
    enable-secrets-manager: true
    private-registry-username-secret: private-charts/username
    private-registry-password-secret: private-charts/password
    
    # Security and validation
    verify-charts: true
    validate-manifests: true
    atomic: true
    wait: true
    timeout: 10m0s
    
    helm-commands: |
      # Deploy infrastructure components from ECR
      helm upgrade --install nginx-ingress \
        oci://123456789012.dkr.ecr.us-west-2.amazonaws.com/charts/nginx-ingress \
        --namespace ingress-nginx \
        --create-namespace \
        --version 4.5.0
      
      # Deploy application with secrets
      helm upgrade --install my-secure-app \
        oci://123456789012.dkr.ecr.us-west-2.amazonaws.com/charts/secure-app \
        --set-string database.password="$(aws-secret prod/db-password)" \
        --set-string api.key="$(aws-secret prod/api-key)" \
        --set image.tag=${{ github.sha }}
```

## 📋 Input Parameters

### Required Parameters

| Parameter | Description |
|-----------|-------------|
| `cluster-name` | EKS cluster name |
| `region` | AWS region where the cluster is located |
| `helm-commands` | Helm commands to execute |

### Private Helm Package Support

| Parameter | Description | Default |
|-----------|-------------|---------|
| `auto-login-ecr` | Automatically login to AWS ECR | `false` |
| `ecr-registry` | Specific ECR registry URL | - |
| `github-packages-token` | GitHub token for GHCR access | - |
| `private-registry-url` | Private Helm registry URL | - |
| `private-registry-username` | Registry username | - |
| `private-registry-password` | Registry password | - |
| `private-registry-username-secret` | Secrets Manager secret for username | - |
| `private-registry-password-secret` | Secrets Manager secret for password | - |
| `additional-registries` | JSON array of additional registries | - |

### Authentication & Access

| Parameter | Description | Default |
|-----------|-------------|---------|
| `role-arn` | IAM role ARN to assume for cluster access | - |
| `assume-role-session-name` | Session name when assuming role | `github-actions-helm-deploy` |

### Private Cluster Support

| Parameter | Description | Default |
|-----------|-------------|---------|
| `private-cluster` | Enable private cluster mode | `false` |
| `bastion-host` | Bastion host for private cluster access | - |
| `bastion-user` | Username for bastion host | `ec2-user` |
| `vpc-endpoint` | VPC endpoint URL for private API access | - |

### Helm Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace` | Kubernetes namespace for operations | `default` |
| `create-namespace` | Create namespace if it doesn't exist | `false` |
| `timeout` | Timeout for Helm operations | `5m0s` |
| `atomic` | Use atomic flag (rollback on failure) | `true` |
| `wait` | Wait for release to be ready | `true` |

### Security Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `verify-charts` | Verify Helm chart signatures | `false` |
| `enable-secrets-manager` | Enable AWS Secrets Manager integration | `false` |
| `secrets-manager-region` | AWS region for Secrets Manager | (cluster region) |
| `validate-manifests` | Validate Kubernetes manifests | `true` |

### Debugging & Operations

| Parameter | Description | Default |
|-----------|-------------|---------|
| `debug` | Enable debug logging | `false` |
| `dry-run` | Perform dry run only | `false` |
| `enable-backup` | Create backup before deployment | `false` |
| `backup-storage` | S3 bucket for backups | - |

## 📤 Outputs

| Output | Description |
|--------|-------------|
| `helm-release-name` | Name of the deployed Helm release |
| `helm-release-revision` | Revision number of the release |
| `kubernetes-resources` | List of created/updated resources |
| `deployment-status` | Status of deployment (success/failure) |

## 🔐 Security Best Practices

### IAM Permissions for Private Charts

#### ECR Access
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    }
  ]
}
```

#### Secrets Manager Access
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:helm/*"
    }
  ]
}
```

### Private Registry Best Practices

1. **Use IAM Roles for ECR**: Prefer IRSA over long-term credentials
2. **Store credentials securely**: Use AWS Secrets Manager for registry credentials
3. **Enable chart verification**: Verify chart signatures in production
4. **Use least privilege**: Grant minimal required permissions
5. **Audit access**: Monitor registry access and deployments

## 🏗️ Architecture with Private Charts

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   GitHub        │    │   GitHub Action  │    │   EKS Cluster   │
│   Actions       │───▶│   Container      │───▶│   (Public/      │
│   Runner        │    │   • ECR Auth     │    │    Private)     │
└─────────────────┘    │   • GHCR Auth    │    └─────────────────┘
                       │   • Private Reg  │
                       └──────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │   Private Charts │
                       │   • AWS ECR      │
                       │   • GitHub GHCR  │
                       │   • Harbor       │
                       │   • Artifactory  │
                       └──────────────────┘
```

## 🔧 Development

### Building Locally

```bash
# Build the Docker image
docker build -t eks-helm-client:latest .

# Test with private ECR
docker run --rm \
  -e INPUT_CLUSTER_NAME=test-cluster \
  -e INPUT_REGION=us-west-2 \
  -e INPUT_AUTO_LOGIN_ECR=true \
  -e INPUT_HELM_COMMANDS="helm version" \
  -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  eks-helm-client:latest
```

### Testing Private Registry Integration

```bash
# Test GitHub Packages
docker run --rm \
  -e INPUT_GITHUB_PACKAGES_TOKEN=$GITHUB_TOKEN \
  -e INPUT_HELM_COMMANDS="helm pull oci://ghcr.io/test/chart" \
  eks-helm-client:latest

# Test private repository
docker run --rm \
  -e INPUT_PRIVATE_REGISTRY_URL=https://charts.example.com \
  -e INPUT_PRIVATE_REGISTRY_USERNAME=testuser \
  -e INPUT_PRIVATE_REGISTRY_PASSWORD=testpass \
  eks-helm-client:latest
```

## 📚 Examples and Use Cases

### Enterprise Multi-Registry Deployment
See [examples/private-helm-examples.yml](examples/private-helm-examples.yml) for comprehensive examples.

### GitOps with Private Charts
Perfect for enterprise environments requiring secure chart distribution.

### Disaster Recovery with Backups
Backup and recovery workflows for production deployments.

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## 📝 Migration from v1.x

### Breaking Changes

- `args` parameter renamed to `helm-commands` for clarity
- Environment variables now use `INPUT_` prefix
- New private registry authentication system

### Migration Steps

1. Update your action version: `@v1.0.0` → `@v2.0.0`
2. Rename `args` to `helm-commands`
3. Configure private registry authentication if needed
4. Update authentication method to use IRSA

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE.md) file for details.

## 🆘 Support

- 📖 [Documentation](https://github.com/open-source-srilanka/eks-helm-client-github-action/wiki)
- 🐛 [Issue Tracker](https://github.com/open-source-srilanka/eks-helm-client-github-action/issues)
- 💬 [Discussions](https://github.com/open-source-srilanka/eks-helm-client-github-action/discussions)
- 📧 [Email Support](mailto:dinushchathurya21@gmail.com)


<p align="center">
    <a href="https://www.patreon.com/bePatron?u=35199964" target="_blank">
        <img src="https://c5.patreon.com/external/logo/become_a_patron_button.png" alt="Become a Patreon">
    </a>
</p>

--- 

## 📤 Author

<p align="center">
    Made with ❤️ & ☕ by <a href="https://dinushchathurya.me/"><u style="color:#0193f0;">Dinush Chathurya</u></a> as a part of <a href="https://github.com/open-source-srilanka"><u style="color:#0193f0;">ProjectOSS</u></a>
</p>  

