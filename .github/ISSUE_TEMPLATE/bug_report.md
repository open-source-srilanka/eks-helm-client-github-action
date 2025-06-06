---
name: Bug report
about: Create a report to help us improve
title: '[BUG] '
labels: ['bug', 'triage']
assignees: ['dinushchathurya']

---

## 🐛 Bug Description

A clear and concise description of what the bug is.

## 🔄 To Reproduce

Steps to reproduce the behavior:

1. Set up workflow with configuration:
   ```yaml
   # Paste your workflow configuration here
   ```

2. Run the action with inputs:
   ```yaml
   with:
     cluster-name: your-cluster
     region: your-region
     # Add other relevant inputs
   ```

3. See error in logs

## ✅ Expected Behavior

A clear and concise description of what you expected to happen.

## ❌ Actual Behavior

What actually happened instead.

## 📊 Environment

**Action Version:** 
- [ ] v1.0.0
- [ ] v2.0.0
- [ ] Other: _____

**Infrastructure:**
- [ ] Public EKS cluster
- [ ] Private EKS cluster
- [ ] Public Helm registry
- [ ] Private Helm registry

**Runner Type:**
- [ ] GitHub-hosted (ubuntu-latest)
- [ ] Self-hosted
- [ ] Other: _____

**AWS Region:** _____

**Tool Versions:**
- kubectl: _____
- Helm: _____
- AWS CLI: _____

## 📝 Configuration

<details>
<summary>Click to expand workflow configuration</summary>

```yaml
# Paste your complete workflow file here
name: Your Workflow Name
on: 
  # Your triggers

jobs:
  deploy:
    runs-on: # Your runner type
    steps:
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          # Your AWS config

      - name: Deploy to EKS
        uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
        with:
          # Your action configuration
```

</details>

<details>
<summary>Click to expand action inputs</summary>

```yaml
# Paste your action configuration here
with:
  cluster-name: 
  region: 
  private-cluster: 
  helm-registry-url: 
  # etc. - include all inputs you're using
```

</details>

## 📜 Error Logs

<details>
<summary>Click to expand error logs</summary>

```
Paste the complete error logs from the GitHub Actions run here.
Include any relevant kubectl, helm, or AWS CLI error messages.

Example sections to include:
- Action startup logs
- AWS credential configuration
- EKS cluster connection attempts
- Helm repository operations
- kubectl commands
- Error stack traces
```

</details>

## 🔍 Additional Context

### Environment Details
- Are you migrating from v1.0.0 to v2.0.0?
- Does this work with other clusters/registries?
- Any network restrictions or VPC configurations?
- Any custom security policies or IAM restrictions?

### Network Configuration (if using private infrastructure)
- VPC CIDR: _____
- Subnet configuration: _____
- Security group rules: _____
- VPC endpoints configured: _____
- NAT Gateway/Instance: _____

### AWS IAM Configuration
- IAM role/user permissions: _____
- EKS cluster auth mode: _____
- Service account configuration: _____

### Helm Registry Details (if using private registry)
- Registry type (Harbor, Nexus, ECR, etc.): _____
- Authentication method: _____
- Registry URL format: _____
- SSL/TLS configuration: _____

## 📎 Screenshots

If applicable, add screenshots of:
- GitHub Actions UI showing the error
- AWS console configurations
- Network/security group settings
- Any relevant error messages

## 🔧 Troubleshooting Already Tried

Please check all that you have already attempted:

- [ ] I have searched existing issues to ensure this is not a duplicate
- [ ] I have included the complete error logs
- [ ] I have provided my workflow configuration
- [ ] I have specified the action version I'm using
- [ ] I have tested with debug mode enabled (`debug: true`)
- [ ] I have verified my AWS credentials and permissions
- [ ] I have confirmed the cluster name and region are correct
- [ ] I have tested with a minimal configuration
- [ ] I have tried increasing the timeout value
- [ ] I have verified network connectivity (for private infrastructure)
- [ ] I have checked VPC endpoints configuration (for private EKS)
- [ ] I have validated Helm registry credentials (for private registries)
- [ ] I have tried with different tool versions
- [ ] I have tested the same configuration locally

### Specific Tests Performed

<details>
<summary>Click to expand testing details</summary>

```bash
# Commands you ran locally to test (if any)
# kubectl commands
# helm commands  
# AWS CLI commands
# Network connectivity tests
```

</details>

## 🚀 Workaround

If you found a temporary workaround, please describe it here to help others with the same issue.

```yaml
# If you have a working configuration, share it here
```

## 🎯 Impact

How is this bug affecting your work?

- [ ] **Critical** - Completely blocking deployment
- [ ] **High** - Blocking some deployments/environments
- [ ] **Medium** - Workaround exists but not ideal
- [ ] **Low** - Minor inconvenience

## 📋 System Information

<details>
<summary>Click to expand system information</summary>

**GitHub Actions Runner:**
- Runner OS: _____
- Runner version: _____
- Docker version: _____

**EKS Cluster:**
- Kubernetes version: _____
- Platform version: _____
- Endpoint access: _____
- Logging enabled: _____

**Network Environment:**
- VPC: _____
- Subnets: _____
- Internet connectivity: _____
- Private DNS: _____

</details>

---

**Thank you for reporting this issue! We'll investigate and respond as soon as possible.**

## 📞 Additional Help

If this is an urgent production issue, you can also:
- 📧 Email: [dinushchathurya21@gmail.com](mailto:dinushchathurya21@gmail.com)
- 💬 Start a discussion for community help
- 📚 Check our troubleshooting guide: [docs/examples/troubleshooting.md](docs/examples/troubleshooting.md)