---
name: Question
about: Ask a question about usage, configuration, or best practices
title: '[QUESTION] '
labels: ['question', 'help wanted']
assignees: []

---

## ❓ Question

### 📝 What's your question?

Please describe what you're trying to understand or accomplish.

### 🎯 Context

#### What are you trying to do?

Describe your goal or use case:

- [ ] **Set up basic EKS deployment** (first time setup)
- [ ] **Configure private EKS cluster access** (private infrastructure)
- [ ] **Set up private Helm registry** (enterprise registries)
- [ ] **Migrate from v1.0.0 to v2.0.0** (upgrade existing workflows)
- [ ] **Troubleshoot connection issues** (debugging problems)
- [ ] **Optimize performance** (improve deployment speed/reliability)
- [ ] **Implement security best practices** (harden configuration)
- [ ] **Understand tool compatibility** (kubectl/Helm versions)
- [ ] **Multi-environment setup** (dev/staging/production)
- [ ] **CI/CD integration** (workflow automation)
- [ ] **Other:** _____

#### Current Setup

**Action Version:** 
- [ ] v1.0.0
- [ ] v2.0.0
- [ ] Other: _____

**Infrastructure:**
- [ ] Public EKS cluster
- [ ] Private EKS cluster
- [ ] Public Helm registry (Docker Hub, Bitnami, etc.)
- [ ] Private Helm registry (Harbor, Nexus, ECR, etc.)

**Runner Environment:**
- [ ] GitHub-hosted runners (ubuntu-latest)
- [ ] Self-hosted runners
- [ ] Specific network configuration: _____

**AWS Region:** _____

**Tool Versions (if known):**
- kubectl: _____
- Helm: _____
- AWS CLI: _____

### 🔧 Current Configuration

<details>
<summary>Click to expand your current workflow</summary>

```yaml
# Paste your current workflow configuration here
# Remove any sensitive information like account IDs, cluster names, etc.

name: Your Workflow
on: 
  # Your triggers

jobs:
  deploy:
    runs-on: # Your runner type
    steps:
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          # Your AWS config (remove sensitive values)

      - name: Deploy to EKS
        uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
        with:
          # Your action configuration
```

</details>

### 🚫 What have you tried?

Describe what you've already attempted:

- [ ] **Read the documentation** (README, examples, migration guide)
- [ ] **Searched existing issues** (GitHub issues, discussions)
- [ ] **Tried different configurations** (various input parameters)
- [ ] **Enabled debug mode** (`debug: true`)
- [ ] **Consulted AWS documentation** (EKS, IAM, VPC)
- [ ] **Tested with dry-run mode** (`dry-run: true`)
- [ ] **Verified credentials and permissions** (AWS, Helm registry)
- [ ] **Checked network connectivity** (VPC, security groups)
- [ ] **Other:** _____

### 📚 Specific Areas

Which areas does your question relate to?

#### Configuration & Setup
- [ ] **Action input parameters** (cluster-name, region, etc.)
- [ ] **AWS credentials setup** (IAM roles, permissions)
- [ ] **kubeconfig configuration** (authentication, access)
- [ ] **Helm repository setup** (public/private registries)
- [ ] **Network connectivity** (VPC, endpoints, security groups)

#### Private Infrastructure
- [ ] **Private EKS cluster networking** (VPC configuration)
- [ ] **VPC endpoints configuration** (AWS services access)
- [ ] **Security groups and NACLs** (network security)
- [ ] **Private registry authentication** (Harbor, Nexus, ECR)
- [ ] **Self-hosted runner setup** (runner configuration)

#### Troubleshooting
- [ ] **Connection timeouts** (slow networks, private infrastructure)
- [ ] **Authentication failures** (AWS, Helm registry)
- [ ] **Permission errors** (IAM, RBAC)
- [ ] **Network connectivity issues** (DNS, routing)
- [ ] **Tool version compatibility** (kubectl, Helm versions)

#### Best Practices
- [ ] **Security recommendations** (least privilege, encryption)
- [ ] **Performance optimization** (timeouts, resource usage)
- [ ] **Cost optimization** (resource efficiency)
- [ ] **CI/CD integration patterns** (workflow design)
- [ ] **Multi-environment workflows** (dev/staging/prod)

#### Migration
- [ ] **v1 to v2 migration** (upgrading from legacy version)
- [ ] **Configuration updates** (parameter changes)
- [ ] **Breaking changes** (compatibility issues)
- [ ] **Feature differences** (new vs old capabilities)

### 📊 Expected Outcome

What outcome are you hoping to achieve?

### 🔗 References

Have you consulted any documentation or resources?

- [ ] [README.md](../../README.md)
- [ ] [Migration Guide](../../docs/MIGRATION.md)
- [ ] [Basic Usage Examples](../../docs/examples/basic-usage.md)
- [ ] [Private Cluster Examples](../../docs/examples/private-cluster.md)
- [ ] [Private Registry Examples](../../docs/examples/private-registry.md)
- [ ] [Advanced Scenarios](../../docs/examples/advanced-scenarios.md)
- [ ] [Troubleshooting Guide](../../docs/examples/troubleshooting.md)
- [ ] AWS EKS documentation
- [ ] Helm documentation
- [ ] Other GitHub Actions documentation
- [ ] **Other:** _____

### 🌟 Additional Context

#### Environment Details
If relevant, please provide:

**AWS Account Setup:**
- Account type: _____
- IAM configuration: _____
- VPC setup: _____

**EKS Cluster Details:**
- Kubernetes version: _____
- Node group type: _____
- Endpoint access: _____
- Logging enabled: _____

**Network Configuration:**
- VPC CIDR: _____
- Subnet configuration: _____
- Internet gateway: _____
- NAT gateway: _____

#### Constraints
Any specific constraints or requirements?

- [ ] **Security requirements** (compliance, regulations)
- [ ] **Network restrictions** (firewall rules, air-gapped)
- [ ] **Compliance requirements** (SOC 2, HIPAA, PCI DSS)
- [ ] **Performance requirements** (deployment time, resource limits)
- [ ] **Cost constraints** (budget limitations)
- [ ] **Tool constraints** (specific versions required)

#### Timeline
Is this question blocking current work?

- [ ] **Urgent** - blocking production deployment
- [ ] **High priority** - needed soon for project timeline
- [ ] **Medium priority** - planning phase, not immediately blocking
- [ ] **Low priority** - learning/exploration, no deadline

## 🎯 Question Categories

*Select the category that best describes your question:*

### Getting Started
- [ ] First time setup with public infrastructure
- [ ] Basic configuration understanding
- [ ] Tool selection and compatibility

### Enterprise Setup
- [ ] Private EKS cluster configuration
- [ ] Private registry integration
- [ ] Enterprise security requirements
- [ ] Multi-account AWS setup

### Advanced Usage
- [ ] Complex deployment patterns
- [ ] Multi-environment management
- [ ] Performance optimization
- [ ] Custom authentication methods

### Troubleshooting
- [ ] Debugging connection issues
- [ ] Understanding error messages
- [ ] Network connectivity problems
- [ ] Permission and access issues

### Migration & Upgrade
- [ ] Upgrading from v1.0.0 to v2.0.0
- [ ] Changing infrastructure setup
- [ ] Tool version upgrades
- [ ] Workflow modernization

---

## 💡 Community Help

Before we answer, you might also find help from:

- **GitHub Discussions**: For broader community input and discussion
- **AWS Support**: For EKS-specific infrastructure questions
- **Helm Community**: For Helm-related configuration questions
- **Stack Overflow**: For general Kubernetes/DevOps questions
- **Documentation**: Our comprehensive examples and guides

## 📞 Additional Resources

- 📚 [Documentation](../../docs/)
- 🔧 [Troubleshooting Guide](../../docs/examples/troubleshooting.md)
- 🚀 [Advanced Examples](../../docs/examples/advanced-scenarios.md)
- 💬 [Community Discussions](https://github.com/open-source-srilanka/eks-helm-client-github-action/discussions)

---

**We'll do our best to help you! Please provide as much detail as possible to get the most accurate answer.**