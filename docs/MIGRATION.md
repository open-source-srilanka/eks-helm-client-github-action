# Migration Guide: v1.0.0 → v2.0.0

This guide helps you migrate from v1.0.0 to v2.0.0 of the EKS Helm Client GitHub Action. Version 2.0.0 introduces comprehensive support for private EKS clusters and private Helm repositories, along with enhanced security and reliability features.

## 🚀 What's New in v2.0.0

### Major Features
- **Private EKS Cluster Support**: Full support for private EKS clusters with VPC endpoints
- **Private Helm Repository Support**: Authentication for Harbor, Nexus, Artifactory, ECR, and custom registries
- **Enhanced Input Parameters**: More flexible configuration options
- **Improved Security**: Better credential handling and cleanup
- **Advanced Debugging**: Comprehensive logging and troubleshooting
- **Network Connectivity Validation**: Automatic testing of cluster and registry connectivity
- **Enhanced Error Handling**: Better error messages and recovery mechanisms

### Tool Updates
- **kubectl**: Updated to v1.28.4 (configurable)
- **Helm**: Updated to v3.13.3 (configurable)
- **Base Image**: Alpine 3.18 for better security
- **AWS IAM Authenticator**: Updated to v0.6.14

## ⚠️ Breaking Changes

### 1. Input Parameter Changes
Some environment variables can now be replaced with input parameters for better flexibility.

**v1.0.0 (Environment Variables Only):**
```yaml
env:
  CLUSTER_NAME: my-cluster
  REGION_CODE: us-west-2
```

**v2.0.0 (Input Parameters Preferred):**
```yaml
with:
  cluster-name: my-cluster
  region: us-west-2
```

### 2. Container User Changes
For better security, the action now runs as a non-root user by default.

### 3. Tool Version Changes
Default tool versions have been updated. If you require specific versions, you can now configure them.

## 🔄 Migration Steps

### Step 1: Update Action Version

**Before (v1.0.0):**
```yaml
- name: Deploy to EKS
  uses: open-source-srilanka/eks-helm-client-github-action@v1.0.0
```

**After (v2.0.0):**
```yaml
- name: Deploy to EKS
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
```

### Step 2: Convert Environment Variables to Input Parameters (Recommended)

**Before (v1.0.0):**
```yaml
- name: Deploy to EKS
  uses: open-source-srilanka/eks-helm-client-github-action@v1.0.0
  env:
    CLUSTER_NAME: my-cluster
    REGION_CODE: us-west-2
  with:
    args: |
      helm upgrade --install my-app bitnami/nginx
```

**After (v2.0.0):**
```yaml
- name: Deploy to EKS
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-cluster
    region: us-west-2
    args: |
      helm upgrade --install my-app bitnami/nginx
```

### Step 3: Test with Dry Run Mode (New Feature)

Before deploying to production, test your migration with dry run mode:

```yaml
- name: Test Migration
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-cluster
    region: us-west-2
    dry-run: true
    debug: true
    args: |
      helm upgrade --install my-app bitnami/nginx --dry-run
```

### Step 4: Update Tool Versions (If Needed)

If you require specific tool versions, configure them:

```yaml
- name: Deploy with Specific Versions
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-cluster
    region: us-west-2
    kubectl-version: "1.27.1"  # Use older version if needed
    helm-version: "3.12.3"     # Use older version if needed
    args: |
      helm upgrade --install my-app bitnami/nginx
```

## 📋 Migration Examples

### Example 1: Basic Public Cluster Migration

**v1.0.0 Configuration:**
```yaml
name: Deploy to EKS
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-west-2

      - name: Deploy to EKS
        uses: open-source-srilanka/eks-helm-client-github-action@v1.0.0
        env:
          CLUSTER_NAME: my-cluster
          REGION_CODE: us-west-2
        with:
          args: |
            helm repo add bitnami https://charts.bitnami.com/bitnami
            helm repo update
            helm upgrade --install my-app bitnami/nginx
```

**v2.0.0 Migrated Configuration:**
```yaml
name: Deploy to EKS
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-west-2

      - name: Deploy to EKS
        uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
        with:
          cluster-name: my-cluster
          region: us-west-2
          # New optional features
          debug: true
          timeout: 600
          args: |
            helm repo add bitnami https://charts.bitnami.com/bitnami
            helm repo update
            helm upgrade --install my-app bitnami/nginx --wait --timeout 10m
```

### Example 2: Adding Private Cluster Support

If you're now using a private EKS cluster, enhance your configuration:

**Enhanced v2.0.0 Configuration for Private Cluster:**
```yaml
name: Deploy to Private EKS
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: self-hosted  # Required for private clusters
    steps:
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/EKSPrivateRole
          aws-region: us-west-2

      - name: Deploy to Private EKS
        uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
        with:
          cluster-name: my-private-cluster
          region: us-west-2
          private-cluster: true
          timeout: 900  # Increased timeout for private networks
          debug: true   # Enhanced debugging for troubleshooting
          args: |
            helm repo add bitnami https://charts.bitnami.com/bitnami
            helm repo update
            helm upgrade --install my-app bitnami/nginx \
              --wait \
              --timeout 15m \
              --namespace production \
              --create-namespace
```

### Example 3: Adding Private Registry Support

Enhance your workflow to use private Helm repositories:

**v2.0.0 with Private Registry:**
```yaml
name: Deploy from Private Registry
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/EKSRole
          aws-region: us-west-2

      - name: Deploy from Harbor Registry
        uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
        with:
          cluster-name: my-cluster
          region: us-west-2
          # New private registry support
          helm-registry-url: https://harbor.company.com/chartrepo/production
          helm-registry-username: ${{ secrets.HARBOR_USERNAME }}
          helm-registry-password: ${{ secrets.HARBOR_PASSWORD }}
          args: |
            helm repo update
            helm upgrade --install my-app private-registry/my-app \
              --namespace production \
              --create-namespace \
              --wait
```

## 🔧 Backward Compatibility

### Environment Variable Support
v2.0.0 maintains backward compatibility with v1.0.0 environment variables:

```yaml
# This v1.0.0 configuration still works in v2.0.0
- name: Deploy to EKS (Backward Compatible)
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  env:
    CLUSTER_NAME: my-cluster  # Still supported
    REGION_CODE: us-west-2    # Still supported
  with:
    args: "helm install my-app bitnami/nginx"
```

### Gradual Migration Approach
You can migrate gradually by mixing environment variables and input parameters:

```yaml
- name: Gradual Migration
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  env:
    CLUSTER_NAME: my-cluster  # v1.0.0 style
  with:
    region: us-west-2         # v2.0.0 style
    debug: true               # v2.0.0 feature
    args: "helm install my-app bitnami/nginx"
```

## 🛠️ Migration Testing Strategy

### 1. Test in Non-Production First
Always test the migration in development or staging environments first:

```yaml
name: Test Migration
on:
  pull_request:
    branches: [main]

jobs:
  test-migration:
    runs-on: ubuntu-latest
    steps:
      - name: Test v2.0.0 Migration
        uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
        with:
          cluster-name: dev-cluster
          region: us-west-2
          dry-run: true  # Test without actual deployment
          debug: true    # Get detailed logs
          args: |
            helm upgrade --install my-app bitnami/nginx --dry-run
```

### 2. Use Debug Mode
Enable debug mode to get detailed information about the migration:

```yaml
- name: Debug Migration
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-cluster
    region: us-west-2
    debug: true  # Enable comprehensive logging
    args: "helm version"  # Simple test command
```

### 3. Validate Tool Versions
Check that the updated tool versions work with your charts:

```yaml
- name: Validate Tool Versions
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-cluster
    region: us-west-2
    args: |
      echo "=== Tool Versions ==="
      kubectl version --client
      helm version
      aws --version
      echo "=== Chart Validation ==="
      helm lint ./charts/my-app
      helm template my-app ./charts/my-app --validate
```

## 🚨 Common Migration Issues

### Issue 1: Permission Errors with Non-Root User

**Problem:**
```
Error: permission denied when writing to /opt/kubernetes/config
```

**Solution:**
This is expected behavior in v2.0.0. The action now handles file permissions automatically. If you see this error, it indicates a configuration issue.

**Fix:**
```yaml
# Ensure you're not manually setting file permissions
- name: Deploy to EKS
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-cluster
    region: us-west-2
    # Let the action handle permissions automatically
    args: "helm install my-app bitnami/nginx"
```

### Issue 2: Tool Version Compatibility

**Problem:**
```
Error: chart requires Helm version >=3.14.0
```

**Solution:**
Specify the required tool version:

```yaml
- name: Deploy with Required Helm Version
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-cluster
    region: us-west-2
    helm-version: "3.14.0"  # Specify required version
    args: "helm install my-app ./charts/my-app"
```

### Issue 3: Timeout Issues

**Problem:**
```
Error: operation timed out after 300 seconds
```

**Solution:**
Increase timeout for complex deployments:

```yaml
- name: Deploy with Extended Timeout
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-cluster
    region: us-west-2
    timeout: 900  # 15 minutes
    args: |
      helm upgrade --install my-app ./charts/my-app \
        --wait \
        --timeout 15m
```

### Issue 4: Private Cluster Connectivity

**Problem:**
```
Error: Unable to connect to the server: dial tcp: lookup xyz.eks.amazonaws.com: no such host
```

**Solution:**
Ensure proper private cluster configuration:

```yaml
- name: Deploy to Private Cluster
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-private-cluster
    region: us-west-2
    private-cluster: true  # Enable private cluster mode
    debug: true            # Get detailed connectivity info
    args: "kubectl cluster-info"
```

## 📊 Migration Checklist

Use this checklist to ensure a successful migration:

### Pre-Migration
- [ ] Review breaking changes in this guide
- [ ] Identify which features you want to adopt (private clusters, private registries, etc.)
- [ ] Plan testing strategy (non-production environments first)
- [ ] Backup existing workflow configurations

### Migration
- [ ] Update action version to `@v2.0.0`
- [ ] Convert environment variables to input parameters (optional but recommended)
- [ ] Add new features as needed (private-cluster, helm-registry-*, etc.)
- [ ] Test with `dry-run: true` first
- [ ] Enable `debug: true` for initial testing

### Post-Migration
- [ ] Test in development environment
- [ ] Test in staging environment
- [ ] Verify tool versions meet requirements
- [ ] Check deployment logs for warnings
- [ ] Update documentation for your team
- [ ] Deploy to production

### Validation
- [ ] Deployments complete successfully
- [ ] All Helm charts work as expected
- [ ] No unexpected timeouts or errors
- [ ] Security features work correctly
- [ ] Monitoring and logging work as expected

## 🆘 Troubleshooting Migration

### Enable Debug Mode
When migrating, always enable debug mode for detailed information:

```yaml
- name: Debug Migration Issues
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-cluster
    region: us-west-2
    debug: true
    args: |
      echo "=== Cluster Info ==="
      kubectl cluster-info
      echo "=== Tool Versions ==="
      kubectl version
      helm version
      echo "=== AWS Identity ==="
      aws sts get-caller-identity
```

### Check Tool Compatibility
Verify that your charts work with the new tool versions:

```yaml
- name: Check Chart Compatibility
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-cluster
    region: us-west-2
    args: |
      # Test chart compatibility
      helm dependency update ./charts/my-app
      helm lint ./charts/my-app
      helm template my-app ./charts/my-app --validate
      
      # Test with specific kubectl version if needed
      kubectl version --client
```

### Rollback Strategy
If you encounter issues, you can temporarily rollback:

```yaml
# Temporary rollback to v1.0.0 if needed
- name: Rollback to v1.0.0
  uses: open-source-srilanka/eks-helm-client-github-action@v1.0.0
  env:
    CLUSTER_NAME: my-cluster
    REGION_CODE: us-west-2
  with:
    args: "helm rollback my-app"
```

## 🔮 Next Steps After Migration

### 1. Explore New Features
After successful migration, explore new v2.0.0 features:

- **Private Cluster Support**: Move to private EKS clusters for enhanced security
- **Private Registry Integration**: Use Harbor, Nexus, or ECR for private charts
- **Enhanced Debugging**: Use debug mode for better troubleshooting
- **Advanced Timeout Control**: Fine-tune timeouts for your environment

### 2. Enhance Security
Leverage v2.0.0 security improvements:

```yaml
- name: Enhanced Security Deployment
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-cluster
    region: us-west-2
    # Enhanced security features
    debug: false  # Disable debug in production
    timeout: 600  # Reasonable timeout
    args: |
      # Use --atomic for safer deployments
      helm upgrade --install my-app ./charts/my-app \
        --atomic \
        --cleanup-on-fail \
        --wait
```

### 3. Optimize Performance
Use new features to optimize your deployments:

```yaml
- name: Optimized Deployment
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-cluster
    region: us-west-2
    # Performance optimizations
    kubectl-version: "1.28.4"  # Latest stable
    helm-version: "3.13.3"     # Latest stable
    timeout: 300               # Optimized timeout
    args: |
      # Parallel operations where possible
      helm repo add bitnami https://charts.bitnami.com/bitnami &
      helm repo add stable https://charts.helm.sh/stable &
      wait
      helm repo update
      helm upgrade --install my-app bitnami/nginx
```

## 📞 Support

If you encounter issues during migration:

1. **Check the troubleshooting guide**: [docs/examples/troubleshooting.md](docs/examples/troubleshooting.md)
2. **Enable debug mode**: Set `debug: true` for detailed logs
3. **Search existing issues**: [GitHub Issues](https://github.com/open-source-srilanka/eks-helm-client-github-action/issues)
4. **Create a new issue**: Include debug logs and configuration
5. **Contact support**: [dinushchathurya21@gmail.com](mailto:dinushchathurya21@gmail.com)

## 📚 Additional Resources

- [v2.0.0 Release Notes](CHANGELOG.md#200---2025-06-05)
- [Basic Usage Examples](docs/examples/basic-usage.md)
- [Private Cluster Examples](docs/examples/private-cluster.md)
- [Private Registry Examples](docs/examples/private-registry.md)
- [Security Best Practices](docs/SECURITY.md)
- [Contributing Guidelines](docs/CONTRIBUTING.md)

---

**Remember**: Migration is a process, not a single step. Take time to test thoroughly and leverage the new features to improve your deployment security and reliability.