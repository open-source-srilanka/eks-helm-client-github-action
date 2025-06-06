---
name: Feature request
about: Suggest an idea for this project
title: '[FEATURE] '
labels: ['enhancement', 'triage']
assignees: ['dinushchathurya']

---

## 🚀 Feature Request

### 📝 Summary

A clear and concise description of the feature you'd like to see added.

### 🎯 Problem Statement

Is your feature request related to a problem? Please describe the problem you're trying to solve.

Example: "I'm always frustrated when [...]"

### 💡 Proposed Solution

Describe the solution you'd like to see implemented.

### 🔄 Alternative Solutions

Describe any alternative solutions or features you've considered.

### 📋 Detailed Description

#### Use Case
Describe the specific use case for this feature:

- **Who:** Who would benefit from this feature?
- **What:** What would they be able to do?
- **Why:** Why is this important?
- **How:** How would they use it?

#### Example Usage

If this feature were implemented, show how you would use it:

```yaml
# Example workflow configuration
steps:
  - name: Use new feature
    uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
    with:
      # New parameters or functionality
      new-feature: true
      new-parameter: "example-value"
      # ... other configuration
      args: |
        # Commands using new feature
        helm deploy with-new-capability
```

### 🏗️ Technical Considerations

#### Scope
- [ ] New input parameter
- [ ] New functionality in existing features
- [ ] Integration with external service
- [ ] Performance improvement
- [ ] Security enhancement
- [ ] Documentation improvement
- [ ] New tool/version support
- [ ] Registry type support
- [ ] Cloud provider integration
- [ ] Other: _____

#### Feature Category
- [ ] **Infrastructure Support** (new cloud providers, cluster types)
- [ ] **Registry Support** (new registry types, authentication methods)
- [ ] **Tool Integration** (new versions, additional tools)
- [ ] **Security Enhancement** (authentication, encryption, compliance)
- [ ] **Usability Improvement** (better UX, error messages, debugging)
- [ ] **Performance Optimization** (faster deployments, resource usage)
- [ ] **Monitoring & Observability** (logging, metrics, tracing)
- [ ] **Enterprise Features** (RBAC, governance, audit trails)

#### Complexity
- [ ] **Simple** (can be implemented quickly, single input/feature)
- [ ] **Medium** (requires some design and testing, multiple components)
- [ ] **Complex** (significant development effort, architectural changes)
- [ ] **Not sure**

#### Dependencies
Are there any dependencies or prerequisites for this feature?

- [ ] Requires new container dependencies
- [ ] Requires AWS service integration
- [ ] Requires Kubernetes version compatibility
- [ ] Requires Helm version compatibility
- [ ] Requires new authentication mechanisms
- [ ] Requires network/infrastructure changes
- [ ] Other: _____

### 🔗 Related Issues

Link any related issues, discussions, or external resources:

- Related Issue: #___
- Related Discussion: #___
- External Reference: [link]
- Similar feature in other tools: [link]

### 📊 Impact Assessment

#### Benefits
What benefits would this feature provide?

- [ ] **Improved security** (better authentication, encryption)
- [ ] **Better performance** (faster deployments, resource efficiency)
- [ ] **Enhanced usability** (easier configuration, better UX)
- [ ] **Broader compatibility** (new platforms, tools, versions)
- [ ] **Cost reduction** (resource optimization, efficiency)
- [ ] **Time savings** (automation, simplified workflows)
- [ ] **Compliance** (regulatory requirements, standards)
- [ ] **Enterprise readiness** (governance, audit, scale)
- [ ] **Developer experience** (debugging, troubleshooting)
- [ ] **Other:** _____

#### Breaking Changes
Would this feature require any breaking changes?

- [ ] **Yes** - would require major version bump (v3.0.0)
- [ ] **No** - backward compatible (minor/patch version)
- [ ] **Unsure** - needs investigation

If breaking changes are required, describe the migration path:

#### Target Users
Who is the primary audience for this feature?

- [ ] **Enterprise users** with private infrastructure
- [ ] **Open source projects** using public infrastructure
- [ ] **CI/CD pipeline users** (automation focus)
- [ ] **Kubernetes/Helm beginners** (ease of use focus)
- [ ] **Advanced DevOps teams** (power user features)
- [ ] **Security-focused organizations** (compliance, audit)
- [ ] **Multi-cloud users** (cross-platform deployments)
- [ ] **All users** (universal benefit)

### 🧪 Testing Strategy

How should this feature be tested?

- [ ] **Unit tests** for individual components
- [ ] **Integration tests** with real EKS clusters
- [ ] **Documentation examples** that users can follow
- [ ] **Community testing/feedback** during beta period
- [ ] **Performance benchmarks** for optimization features
- [ ] **Security validation** for security-related features
- [ ] **Compatibility testing** across different environments

### 📚 Documentation

What documentation would be needed?

- [ ] **README updates** (input parameters, examples)
- [ ] **New example workflows** in docs/examples/
- [ ] **Migration guide updates** (if breaking changes)
- [ ] **Troubleshooting documentation** (common issues)
- [ ] **API reference updates** (input parameters)
- [ ] **Security documentation** (for security features)
- [ ] **Performance guidelines** (for optimization features)

### 🗓️ Priority

How important is this feature to you?

- [ ] **Critical** - blocking current work, urgent business need
- [ ] **High** - would significantly improve workflow/productivity
- [ ] **Medium** - nice to have improvement, moderate impact
- [ ] **Low** - minor enhancement, low impact

### 💭 Additional Context

Add any other context, mockups, or examples about the feature request here.

#### Similar Features
Are there similar features in other GitHub Actions or tools?

#### Community Interest
Have you discussed this with others who might benefit?

#### Business Case
If this is for enterprise use, what's the business justification?

## 🎯 Specific Feature Categories

*Check the most relevant category and provide specific details:*

### Infrastructure Support
- [ ] **New Cloud Provider:** AWS, Azure, GCP, others
- [ ] **New Cluster Type:** EKS Fargate, self-managed, hybrid
- [ ] **Network Configuration:** VPN, Direct Connect, custom networking

<details>
<summary>Infrastructure details</summary>

```yaml
# Describe the infrastructure integration
provider: aws/azure/gcp
cluster-type: fargate/self-managed
network-config: vpn/direct-connect
```

</details>

### Registry Support
- [ ] **New Registry Type:** Docker Hub, Quay, custom
- [ ] **Authentication Method:** OIDC, certificates, API keys
- [ ] **Protocol Support:** OCI, traditional Helm

<details>
<summary>Registry details</summary>

```yaml
# Describe the registry integration
registry-type: harbor/nexus/artifactory/custom
auth-method: basic/oidc/cert/api-key
protocol: oci/helm
```

</details>

### Tool Integration
- [ ] **New Tool Version:** kubectl 1.29+, Helm 3.14+
- [ ] **Additional Tools:** kustomize, skaffold, flux
- [ ] **CI/CD Integration:** specific pipeline tools

<details>
<summary>Tool details</summary>

```yaml
# Describe the tool integration
tool: kubectl/helm/kustomize/other
version: specific version requirement
integration: how it would work with existing tools
```

</details>

---

**Thank you for suggesting this feature! We'll review it and provide feedback on feasibility and implementation timeline.**

## 📞 Community Discussion

Consider starting a discussion to gather community input:
- 💬 [GitHub Discussions](https://github.com/open-source-srilanka/eks-helm-client-github-action/discussions)
- 📧 Email: [dinushchathurya21@gmail.com](mailto:dinushchathurya21@gmail.com)

## 📚 References

- [Contributing Guidelines](docs/CONTRIBUTING.md)
- [Current Examples](docs/examples/)
- [Security Policy](docs/SECURITY.md)