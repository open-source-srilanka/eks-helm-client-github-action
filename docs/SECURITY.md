# Security Policy

## Overview

The EKS Helm Client GitHub Action is designed with security as a primary concern. This document outlines our security practices, how to report vulnerabilities, and the security features built into the action, including comprehensive security measures for private Helm package deployments.

## Security Features

### 🔒 Container Security

- **Non-root execution**: The action runs as a non-privileged user (`runner` with UID 1001)
- **Minimal base image**: Uses Alpine Linux with only necessary packages
- **Regular security updates**: Base image and dependencies are updated regularly
- **Multi-layer scanning**: Images are scanned for vulnerabilities using Trivy and other tools

### 🛡️ Authentication & Authorization

- **IAM Roles for Service Accounts (IRSA)**: Recommended authentication method
- **Temporary credentials**: Uses AWS STS for temporary, scoped access
- **Role assumption**: Support for cross-account and restricted role access
- **Principle of least privilege**: Only requests necessary permissions

### 🔐 Data Protection

- **Secrets management**: Integration with AWS Secrets Manager
- **No credential logging**: Sensitive data is never logged or exposed
- **Temporary file cleanup**: All temporary files are securely removed
- **Environment isolation**: Each run operates in an isolated container

### 🌐 Network Security

- **Private cluster support**: Full support for private EKS clusters
- **VPC endpoint integration**: Uses private endpoints when available
- **TLS verification**: Always verifies TLS certificates
- **Network policies**: Respects Kubernetes network policies

### 📦 Private Registry Security

- **Multi-registry authentication**: Secure authentication for multiple private registries
- **Registry credential isolation**: Credentials are isolated per registry and cleaned after use
- **OCI compliance**: Full support for OCI-compliant registries with secure authentication
- **Chart signature verification**: Optional verification of Helm chart signatures
- **Registry access logging**: Comprehensive logging of registry authentication attempts

### 📋 Supply Chain Security

- **Chart verification**: Optional Helm chart signature verification
- **Checksum validation**: All downloaded binaries are checksum verified
- **Dependency pinning**: All tool versions are explicitly pinned
- **Reproducible builds**: Builds are reproducible and auditable
- **Private chart security**: Secure handling of private chart credentials and authentication

## Supported Security Configurations

### IAM Roles for Service Accounts (IRSA) - Recommended

```yaml
- name: Configure AWS Credentials with IRSA
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::123456789012:role/EKSHelmDeploymentRole
    role-session-name: github-actions-deployment
    aws-region: us-west-2

- name: Deploy with IRSA
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: production-cluster
    region: us-west-2
    auto-login-ecr: true
    verify-charts: true
    validate-manifests: true
```

### Cross-Account Role Assumption

```yaml
- name: Deploy to Cross-Account Cluster
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: shared-cluster
    region: us-west-2
    role-arn: arn:aws:iam::987654321098:role/CrossAccountEKSAccess
    assume-role-session-name: github-actions-cross-account
```

### Private Cluster with Enhanced Security

```yaml
- name: Deploy to Private Cluster
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: private-production
    region: us-west-2
    private-cluster: true
    vpc-endpoint: https://vpce-12345.eks.us-west-2.vpce.amazonaws.com
    verify-charts: true
    enable-secrets-manager: true
    auto-login-ecr: true
```

## Required IAM Permissions

### Minimum Permissions for Public Clusters

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster"
      ],
      "Resource": "arn:aws:eks:*:*:cluster/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
```

### Enhanced Permissions for Private Registry Support

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": "arn:aws:eks:*:*:cluster/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity",
        "sts:AssumeRole"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:helm/*",
      "Condition": {
        "StringEquals": {
          "secretsmanager:ResourceTag/Environment": ["production", "staging"]
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::your-helm-backups/*"
    }
  ]
}
```

### Cross-Account ECR Access

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "arn:aws:ecr:*:ACCOUNT-ID:repository/*"
    }
  ]
}
```

## Security Best Practices

### 1. Use IRSA Instead of Long-Term Credentials

❌ **Don't use long-term AWS access keys**:
```yaml
# DON'T DO THIS
env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

✅ **Use IRSA for temporary credentials**:
```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ vars.AWS_ROLE_ARN }}
    role-session-name: github-actions-deployment
```

### 2. Secure Private Registry Authentication

✅ **Use AWS Secrets Manager for registry credentials**:
```yaml
- name: Deploy with Secure Registry Auth
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    enable-secrets-manager: true
    private-registry-username-secret: helm/registry/username
    private-registry-password-secret: helm/registry/password
```

❌ **Don't use plain text credentials**:
```yaml
# DON'T DO THIS
with:
  private-registry-username: myuser
  private-registry-password: mypassword
```

### 3. Enable Chart Verification for Production

```yaml
- name: Deploy with Verified Charts
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    verify-charts: true
    helm-commands: |
      helm repo add bitnami https://charts.bitnami.com/bitnami
      helm repo update
      helm install my-app bitnami/nginx --verify
```

### 4. Use ECR for Private Charts in AWS

```yaml
- name: Secure ECR Deployment
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    auto-login-ecr: true
    helm-commands: |
      helm upgrade --install my-app \
        oci://123456789012.dkr.ecr.us-west-2.amazonaws.com/charts/my-app \
        --version 1.0.0
```

### 5. Validate Manifests Before Deployment

```yaml
- name: Deploy with Validation
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    validate-manifests: true
    atomic: true
    wait: true
```

### 6. Use Private Clusters for Production

```yaml
- name: Deploy to Private Production Cluster
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: private-prod
    private-cluster: true
    vpc-endpoint: ${{ vars.PRIVATE_VPC_ENDPOINT }}
    auto-login-ecr: true
    verify-charts: true
```

## Private Registry Security Guidelines

### AWS ECR Security

1. **Use IRSA**: Always prefer IAM roles over access keys
2. **Least privilege**: Grant minimal ECR permissions
3. **Cross-account access**: Use resource-based policies for shared registries
4. **Image scanning**: Enable ECR vulnerability scanning
5. **Lifecycle policies**: Implement image retention policies

### GitHub Container Registry Security

1. **Token scope**: Use tokens with minimal required scopes
2. **Package visibility**: Set appropriate package visibility (private for sensitive charts)
3. **Access control**: Use GitHub teams for package access control
4. **Audit logs**: Monitor package access through GitHub audit logs

### Private Repository Security

1. **HTTPS only**: Always use HTTPS for repository connections
2. **Strong authentication**: Use strong passwords or tokens
3. **Certificate validation**: Never skip TLS certificate validation
4. **Access logging**: Monitor repository access logs
5. **Regular rotation**: Rotate credentials regularly

### Multi-Registry Security

1. **Credential isolation**: Each registry uses separate credentials
2. **Secure storage**: Store all credentials in AWS Secrets Manager
3. **Access auditing**: Log all registry authentication attempts
4. **Failure handling**: Fail securely if authentication fails

## Private Cluster Security Configuration

### VPC Endpoints Required

For private clusters, ensure these VPC endpoints are configured:

- **EKS API Server**: `com.amazonaws.region.eks`
- **EC2**: `com.amazonaws.region.ec2`
- **ECR API**: `com.amazonaws.region.ecr.api`
- **ECR DKR**: `com.amazonaws.region.ecr.dkr`
- **S3**: `com.amazonaws.region.s3`
- **Secrets Manager**: `com.amazonaws.region.secretsmanager`

### Security Group Rules

```bash
# Allow HTTPS traffic to VPC endpoints
aws ec2 authorize-security-group-ingress \
  --group-id sg-12345678 \
  --protocol tcp \
  --port 443 \
  --source-group sg-87654321

# Allow ECR traffic for private registries
aws ec2 authorize-security-group-ingress \
  --group-id sg-12345678 \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0
```

## Registry-Specific Security Considerations

### ECR Security Checklist

- [ ] IRSA configured for ECR access
- [ ] Cross-account policies configured (if needed)
- [ ] Image vulnerability scanning enabled
- [ ] Lifecycle policies implemented
- [ ] Registry access logging enabled
- [ ] Network access restricted to VPC

### GitHub Packages Security Checklist

- [ ] Fine-grained personal access token used
- [ ] Token scope limited to packages:read
- [ ] Package visibility set to private
- [ ] Team-based access control configured
- [ ] Regular token rotation scheduled
- [ ] Audit log monitoring enabled

### Private Registry Security Checklist

- [ ] HTTPS enforced for all connections
- [ ] Strong authentication configured
- [ ] Credentials stored in Secrets Manager
- [ ] TLS certificate validation enabled
- [ ] Access logging configured
- [ ] Regular credential rotation
- [ ] Network access restricted

## Vulnerability Reporting

### Reporting Security Vulnerabilities

We take security vulnerabilities seriously. Please report security issues responsibly:

1. **DO NOT** create public GitHub issues for security vulnerabilities
2. **Email us directly**: [dinushchathurya21@gmail.com](mailto:dinushchathurya21@gmail.com)
3. **Use encrypted communication** when possible

### What to Include in Your Report

- **Description**: Clear description of the vulnerability
- **Impact**: Potential impact and attack scenarios
- **Reproduction**: Step-by-step instructions to reproduce
- **Environment**: Affected versions and configurations
- **Proof of Concept**: If applicable, include PoC code
- **Registry specifics**: If related to private registry authentication

### Our Response Process

1. **Acknowledgment**: We'll acknowledge receipt within 24 hours
2. **Assessment**: Initial assessment within 72 hours
3. **Updates**: Regular updates on progress
4. **Resolution**: Coordinated disclosure after fix is available

## Security Monitoring

### Automated Security Checks

Our CI/CD pipeline includes:

- **Container vulnerability scanning** with Trivy
- **Dependency vulnerability scanning** with Snyk
- **Static code analysis** with CodeQL
- **Secret detection** with GitLeaks
- **Infrastructure as Code scanning** with Checkov
- **Registry authentication testing**

### Security Notifications

- **Security advisories**: Published for all security updates
- **CVE tracking**: We track and respond to relevant CVEs
- **Dependency monitoring**: Automated monitoring of dependencies
- **Registry security alerts**: Notifications for registry-related security issues

## Compliance

### Standards Compliance

This action is designed to support compliance with:

- **SOC 2 Type II**: Security controls and monitoring
- **ISO 27001**: Information security management
- **PCI DSS**: For applications handling payment data
- **HIPAA**: For healthcare applications (when properly configured)
- **FedRAMP**: For government cloud deployments

### Audit Trail

- **Deployment logs**: Comprehensive logging of all operations
- **Access logs**: AWS CloudTrail integration
- **Change tracking**: Git-based change tracking
- **Backup records**: Automated backup and recovery logs
- **Registry access logs**: Authentication and pull logs for private registries

## Security Updates

### Update Schedule

- **Critical vulnerabilities**: Immediate patches
- **High severity**: Within 48 hours
- **Medium/Low severity**: Next scheduled release
- **Dependency updates**: Monthly security updates
- **Registry security updates**: As needed for new threats

### Staying Informed

- **Watch this repository** for security updates
- **Subscribe to security advisories** on GitHub
- **Follow release notes** for security-related changes
- **Monitor registry security bulletins**

## Contact

For security-related questions or concerns:

- **Security Issues**: [dinushchathurya21@gmail.com](mailto:dinushchathurya21@gmail.com)
- **General Questions**: [GitHub Discussions](https://github.com/open-source-srilanka/eks-helm-client-github-action/discussions)
- **Documentation**: [Wiki](https://github.com/open-source-srilanka/eks-helm-client-github-action/wiki)

---

**Remember**: Security is a shared responsibility. This action provides secure defaults and features for private registry authentication, but your overall security posture depends on proper configuration and following security best practices in your infrastructure, registry management, and deployment processes. 