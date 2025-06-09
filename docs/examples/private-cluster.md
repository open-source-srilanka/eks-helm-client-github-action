# Private EKS Cluster Examples

This guide provides comprehensive examples for deploying Helm charts to private Amazon EKS clusters that don't have public endpoints. Private clusters require special network configuration and self-hosted runners.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Network Architecture](#network-architecture)
- [Self-Hosted Runner Setup](#self-hosted-runner-setup)
- [VPC Endpoints Configuration](#vpc-endpoints-configuration)
- [Basic Private Cluster Deployment](#basic-private-cluster-deployment)
- [Private Registry with Private Cluster](#private-registry-with-private-cluster)
- [Advanced Network Configurations](#advanced-network-configurations)
- [Troubleshooting Private Clusters](#troubleshooting-private-clusters)
- [Security Best Practices](#security-best-practices)

## Prerequisites

### Network Requirements

1. **Self-hosted GitHub Runner** in the same VPC or with VPC connectivity
2. **VPC Endpoints** for AWS services
3. **Security Groups** allowing HTTPS traffic (port 443)
4. **Private DNS** resolution for EKS endpoint
5. **NAT Gateway** or **Internet Gateway** for external dependencies (optional)

### AWS Services VPC Endpoints Required

```bash
# Required VPC endpoints for private EKS
com.amazonaws.region.eks
com.amazonaws.region.sts
com.amazonaws.region.ec2
com.amazonaws.region.ecr.api      # If using ECR
com.amazonaws.region.ecr.dkr      # If using ECR
com.amazonaws.region.s3           # For pulling images
com.amazonaws.region.logs         # For CloudWatch logs
com.amazonaws.region.secretsmanager  # If using Secrets Manager
```

## Network Architecture

### Typical Private EKS Setup

```
┌─────────────────────────────────────────────────────────────┐
│                           VPC                                 │
│  ┌─────────────────────┐    ┌─────────────────────┐        │
│  │  Private Subnet 1    │    │  Private Subnet 2    │        │
│  │                      │    │                      │        │
│  │  ┌────────────────┐ │    │  ┌────────────────┐ │        │
│  │  │ Self-Hosted    │ │    │  │ EKS Worker     │ │        │
│  │  │ GitHub Runner  │ │    │  │ Nodes          │ │        │
│  │  └────────────────┘ │    │  └────────────────┘ │        │
│  └─────────────────────┘    └─────────────────────┘        │
│                                                              │
│  ┌─────────────────────────────────────────────────┐        │
│  │            VPC Endpoints Subnet                  │        │
│  │  - EKS Endpoint                                  │        │
│  │  - STS Endpoint                                  │        │
│  │  - EC2 Endpoint                                  │        │
│  │  - ECR Endpoints                                 │        │
│  │  - S3 Endpoint                                   │        │
│  └─────────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

## Self-Hosted Runner Setup

### EC2 User Data Script for GitHub Runner

```bash
#!/bin/bash
# EC2 User Data for GitHub Actions Runner

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker

# Install required tools
yum install -y git jq

# Create runner user
useradd -m -s /bin/bash runner
usermod -aG docker runner

# Download and install GitHub Actions runner
su - runner << 'EOF'
mkdir actions-runner && cd actions-runner
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz

# Configure runner (replace with your values)
./config.sh --url https://github.com/YOUR_ORG/YOUR_REPO \
  --token YOUR_RUNNER_TOKEN \
  --name private-eks-runner \
  --labels private-eks,self-hosted,linux,x64 \
  --unattended \
  --replace

# Install as service
sudo ./svc.sh install
sudo ./svc.sh start
EOF

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
```

### GitHub Workflow with Self-Hosted Runner

```yaml
name: Deploy to Private EKS
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: [self-hosted, private-eks]  # Use self-hosted runner
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.PRIVATE_EKS_ROLE_ARN }}
          aws-region: us-west-2

      - name: Deploy to Private EKS
        uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
        with:
          cluster-name: private-eks-cluster
          region: us-west-2
          private-cluster: true  # Enable private cluster mode
          timeout: 900          # Increased timeout for private networks
          debug: true           # Enable debug logging
          args: |
            helm upgrade --install my-app ./charts/my-app \
              --namespace production \
              --create-namespace \
              --wait
```

## VPC Endpoints Configuration

### Terraform Example for VPC Endpoints

```hcl
# VPC Endpoints for Private EKS
resource "aws_vpc_endpoint" "eks" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.eks"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.endpoint[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "eks-vpc-endpoint"
  }
}

resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.endpoint[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "sts-vpc-endpoint"
  }
}

resource "aws_vpc_endpoint" "ec2" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.endpoint[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "ec2-vpc-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.endpoint[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "ecr-api-vpc-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.endpoint[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "ecr-dkr-vpc-endpoint"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id

  tags = {
    Name = "s3-vpc-endpoint"
  }
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "vpc-endpoints-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "Allow HTTPS from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "vpc-endpoints-sg"
  }
}
```

### AWS CLI Commands for VPC Endpoints

```bash
# Create VPC endpoint for EKS
aws ec2 create-vpc-endpoint \
  --vpc-id vpc-12345678 \
  --service-name com.amazonaws.us-west-2.eks \
  --vpc-endpoint-type Interface \
  --subnet-ids subnet-12345678 subnet-87654321 \
  --security-group-ids sg-12345678 \
  --private-dns-enabled

# Create VPC endpoint for STS
aws ec2 create-vpc-endpoint \
  --vpc-id vpc-12345678 \
  --service-name com.amazonaws.us-west-2.sts \
  --vpc-endpoint-type Interface \
  --subnet-ids subnet-12345678 subnet-87654321 \
  --security-group-ids sg-12345678 \
  --private-dns-enabled

# Verify endpoints
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=vpc-12345678" \
  --query "VpcEndpoints[*].[ServiceName,State,VpcEndpointId]" \
  --output table
```

## Basic Private Cluster Deployment

### Minimal Configuration

```yaml
name: Deploy to Private EKS
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: [self-hosted, private-eks]
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Deploy to Private Cluster
        uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
        with:
          cluster-name: private-eks-prod
          region: us-west-2
          private-cluster: true
          args: |
            # Simple deployment
            helm upgrade --install nginx bitnami/nginx \
              --namespace default \
              --wait
```

### With Network Validation

```yaml
- name: Deploy with Network Checks
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: private-eks-prod
    region: us-west-2
    private-cluster: true
    debug: true
    timeout: 1200  # 20 minutes for private network latency
    args: |
      # Verify cluster connectivity
      echo "Testing cluster connectivity..."
      kubectl cluster-info
      
      # Check node status
      echo "Checking node status..."
      kubectl get nodes
      
      # Verify namespace access
      echo "Checking namespaces..."
      kubectl get namespaces
      
      # Deploy application
      echo "Deploying application..."
      helm upgrade --install my-app ./charts/my-app \
        --namespace production \
        --create-namespace \
        --wait \
        --timeout 15m
```

## Private Registry with Private Cluster

### Using ECR with Private Endpoints

```yaml
- name: Login to Amazon ECR
  uses: aws-actions/amazon-ecr-login@v2

- name: Deploy from ECR
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: private-eks-prod
    region: us-west-2
    private-cluster: true
    args: |
      # Deploy using ECR images
      helm upgrade --install my-app ./charts/my-app \
        --namespace production \
        --set image.repository=${{ secrets.ECR_REGISTRY }}/my-app \
        --set image.tag=${{ github.sha }} \
        --wait
```

### Using Private Harbor Registry

```yaml
- name: Deploy from Private Harbor
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: private-eks-prod
    region: us-west-2
    private-cluster: true
    helm-registry-url: https://harbor.internal.company.com
    helm-registry-username: ${{ secrets.HARBOR_USERNAME }}
    helm-registry-password: ${{ secrets.HARBOR_PASSWORD }}
    args: |
      # Add and update private repository
      helm repo update
      
      # Deploy from private Harbor
      helm upgrade --install my-app private-registry/my-app \
        --namespace production \
        --version 1.2.3 \
        --wait
```

## Advanced Network Configurations

### Multi-AZ Private Deployment

```yaml
name: Multi-AZ Private Deployment
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: [self-hosted, private-eks]
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.PRIVATE_EKS_ROLE_ARN }}
          aws-region: us-west-2

      - name: Deploy to Multi-AZ Private Cluster
        uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
        with:
          cluster-name: private-eks-multi-az
          region: us-west-2
          private-cluster: true
          args: |
            # Deploy with pod anti-affinity for multi-AZ
            helm upgrade --install my-app ./charts/my-app \
              --namespace production \
              --set replicaCount=6 \
              --set affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].labelSelector.matchExpressions[0].key=app \
              --set affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].labelSelector.matchExpressions[0].operator=In \
              --set affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].labelSelector.matchExpressions[0].values[0]=my-app \
              --set affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].topologyKey=topology.kubernetes.io/zone \
              --wait
```

### Transit Gateway Configuration

```yaml
- name: Deploy Across VPCs via Transit Gateway
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: private-eks-tgw
    region: us-west-2
    private-cluster: true
    timeout: 1800  # 30 minutes for cross-VPC latency
    args: |
      # Verify cross-VPC connectivity
      echo "Testing Transit Gateway connectivity..."
      
      # Deploy application that connects to services in other VPCs
      helm upgrade --install cross-vpc-app ./charts/cross-vpc-app \
        --namespace production \
        --set database.endpoint=db.vpc2.internal \
        --set cache.endpoint=redis.vpc3.internal \
        --set networking.mode=transit-gateway \
        --wait
```

### Private Link Services

```yaml
- name: Deploy with PrivateLink
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: private-eks-privatelink
    region: us-west-2
    private-cluster: true
    args: |
      # Deploy service exposed via PrivateLink
      helm upgrade --install api-service ./charts/api-service \
        --namespace production \
        --set service.type=LoadBalancer \
        --set service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
        --set service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-internal"="true" \
        --set service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-cross-zone-load-balancing-enabled"="true" \
        --wait
      
      # Get the NLB ARN for PrivateLink configuration
      NLB_NAME=$(kubectl get svc api-service -n production -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' | cut -d'-' -f1)
      echo "NLB Name for PrivateLink: $NLB_NAME"
```

## Troubleshooting Private Clusters

### Connectivity Testing

```yaml
- name: Troubleshoot Private Cluster
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: private-eks-prod
    region: us-west-2
    private-cluster: true
    debug: true
    args: |
      # Test DNS resolution
      echo "=== DNS Resolution Test ==="
      nslookup ${CLUSTER_NAME}.eks.${REGION_CODE}.amazonaws.com
      
      # Test EKS API connectivity
      echo "=== EKS API Connectivity Test ==="
      curl -I https://${CLUSTER_NAME}.eks.${REGION_CODE}.amazonaws.com --connect-timeout 10 || echo "Connection failed"
      
      # Check VPC endpoints
      echo "=== VPC Endpoints Status ==="
      aws ec2 describe-vpc-endpoints --region ${REGION_CODE} \
        --query "VpcEndpoints[?State=='Available'].[ServiceName,VpcEndpointId]" \
        --output table
      
      # Test kubectl connectivity
      echo "=== Kubectl Connectivity Test ==="
      kubectl cluster-info dump --output-directory=/tmp/cluster-dump || echo "Kubectl failed"
      
      # Check security groups
      echo "=== Security Groups Check ==="
      aws ec2 describe-security-groups --region ${REGION_CODE} \
        --filters "Name=group-name,Values=*eks*" \
        --query "SecurityGroups[*].[GroupName,GroupId]" \
        --output table
```

### Network Path Analysis

```yaml
- name: Analyze Network Path
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: private-eks-prod
    region: us-west-2
    private-cluster: true
    debug: true
    args: |
      # Get runner's network information
      echo "=== Runner Network Info ==="
      ip addr show
      ip route show
      cat /etc/resolv.conf
      
      # Test connectivity to various endpoints
      echo "=== Endpoint Connectivity Tests ==="
      
      # Test EKS endpoint
      nc -zv ${CLUSTER_NAME}.eks.${REGION_CODE}.amazonaws.com 443 || echo "EKS endpoint unreachable"
      
      # Test STS endpoint
      nc -zv sts.${REGION_CODE}.amazonaws.com 443 || echo "STS endpoint unreachable"
      
      # Test ECR endpoints
      nc -zv ${ACCOUNT_ID}.dkr.ecr.${REGION_CODE}.amazonaws.com 443 || echo "ECR endpoint unreachable"
      
      # Traceroute to EKS endpoint
      echo "=== Traceroute to EKS ==="
      traceroute -T -p 443 ${CLUSTER_NAME}.eks.${REGION_CODE}.amazonaws.com || echo "Traceroute failed"
```

### Debug Mode Deployment

```yaml
- name: Debug Private Cluster Issues
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  env:
    # Enable AWS CLI debug logging
    AWS_DEBUG: "true"
    # Enable Kubernetes debug logging
    KUBE_VERBOSE: "9"
  with:
    cluster-name: private-eks-prod
    region: us-west-2
    private-cluster: true
    debug: true
    timeout: 3600  # 1 hour for debugging
    args: |
      # Enable Helm debug mode
      export HELM_DEBUG=true
      
      # Test with increased verbosity
      helm list --all-namespaces --debug
      
      # Dry run with debug
      helm upgrade --install my-app ./charts/my-app \
        --namespace production \
        --debug \
        --dry-run
      
      # If dry run succeeds, deploy with debug
      helm upgrade --install my-app ./charts/my-app \
        --namespace production \
        --debug \
        --wait \
        --timeout 30m
```

## Security Best Practices

### IAM Roles and Policies

```yaml
# Minimal IAM policy for private EKS deployment
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": "arn:aws:eks:us-west-2:123456789012:cluster/private-eks-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sts:AssumeRole"
      ],
      "Resource": "arn:aws:iam::123456789012:role/EKSPrivateClusterRole"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeVpcEndpoints",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "us-west-2"
        }
      }
    }
  ]
}
```

### Network Security

```yaml
- name: Deploy with Network Policies
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: private-eks-secure
    region: us-west-2
    private-cluster: true
    args: |
      # Apply network policy before deployment
      kubectl apply -f - <<EOF
      apiVersion: networking.k8s.io/v1
      kind: NetworkPolicy
      metadata:
        name: production-network-policy
        namespace: production
      spec:
        podSelector:
          matchLabels:
            environment: production
        policyTypes:
        - Ingress
        - Egress
        ingress:
        - from:
          - namespaceSelector:
              matchLabels:
                name: production
          - namespaceSelector:
              matchLabels:
                name: monitoring
          ports:
          - protocol: TCP
            port: 8080
        egress:
        - to:
          - namespaceSelector:
              matchLabels:
                name: production
          ports:
          - protocol: TCP
            port: 5432
        - to:
          - namespaceSelector: {}
          ports:
          - protocol: TCP
            port: 53
          - protocol: UDP
            port: 53
      EOF
      
      # Deploy application with network policy
      helm upgrade --install secure-app ./charts/secure-app \
        --namespace production \
        --set networkPolicy.enabled=true \
        --wait
```

### Secrets Management

```yaml
- name: Deploy with AWS Secrets Manager
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: private-eks-prod
    region: us-west-2
    private-cluster: true
    args: |
      # Install Secrets Store CSI Driver if not present
      helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
      helm upgrade --install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
        --namespace kube-system \
        --set syncSecret.enabled=true
      
      # Install AWS Provider
      kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml
      
      # Deploy application with secrets from AWS Secrets Manager
      helm upgrade --install my-app ./charts/my-app \
        --namespace production \
        --set secrets.provider=aws-secrets-manager \
        --set secrets.storeName=production-secrets \
        --wait
```

## Best Practices Summary

1. **Always use self-hosted runners** in the same VPC as your private EKS cluster
2. **Configure all required VPC endpoints** before attempting deployment
3. **Enable private DNS** for VPC endpoints to ensure proper resolution
4. **Use appropriate timeouts** as private networks may have higher latency
5. **Enable debug mode** for initial setup and troubleshooting
6. **Implement network policies** to control traffic flow
7. **Use IAM roles** instead of long-lived credentials
8. **Monitor VPC endpoint costs** as they can accumulate
9. **Implement proper logging** for audit and troubleshooting
10. **Test connectivity** before attempting deployments

## Common Issues and Solutions

### Issue: Connection Timeout

**Solution:**
```bash
# Increase timeout values
timeout: 1800  # 30 minutes
# Check security group rules
# Verify VPC endpoints are active
```

### Issue: DNS Resolution Failure

**Solution:**
```bash
# Enable private DNS on VPC endpoints
# Check Route 53 resolver rules
# Verify DHCP options set
```

### Issue: Authentication Failure

**Solution:**
```bash
# Verify IAM role trust policy
# Check STS VPC endpoint
# Ensure aws-auth ConfigMap is updated
```

## Next Steps

- Review [Basic Usage Examples](basic-usage.md) for general deployment patterns
- Check [Private Registry Examples](private-registry.md) for registry integration
- See [Advanced Scenarios](advanced-scenarios.md) for complex deployments
- Consult [Troubleshooting Guide](troubleshooting.md) for common issues

---

**Need Help?** For private cluster issues, ensure all network requirements are met before [opening an issue](https://github.com/open-source-srilanka/eks-helm-client-github-action/issues)