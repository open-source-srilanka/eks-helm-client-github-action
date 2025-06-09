# Basic Usage Examples

This guide provides basic examples for using the EKS Helm Client GitHub Action. These examples cover common scenarios for deploying Helm charts to Amazon EKS clusters.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Basic Deployment](#basic-deployment)
- [Helm Repository Management](#helm-repository-management)
- [Deploying from Different Sources](#deploying-from-different-sources)
- [Environment-Specific Deployments](#environment-specific-deployments)
- [Using Values Files](#using-values-files)
- [Rollback and History](#rollback-and-history)
- [Namespace Management](#namespace-management)
- [Common Patterns](#common-patterns)

## Prerequisites

Before using these examples, ensure you have:

1. An AWS account with an EKS cluster
2. GitHub repository with your Helm charts or application code
3. AWS credentials configured in GitHub Secrets
4. Basic understanding of Helm and Kubernetes

### Required GitHub Secrets

```yaml
AWS_ACCESS_KEY_ID: your-access-key-id
AWS_SECRET_ACCESS_KEY: your-secret-access-key
# Or use OIDC with IAM roles (recommended)
AWS_ROLE_ARN: arn:aws:iam::123456789012:role/GitHubActionsRole
```

## Basic Deployment

### Simple Helm Install

The most basic usage - deploying a chart from a public repository:

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

      - name: Deploy Nginx to EKS
        uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
        with:
          cluster-name: my-eks-cluster
          region: us-west-2
          args: |
            helm repo add bitnami https://charts.bitnami.com/bitnami
            helm repo update
            helm install my-nginx bitnami/nginx
```

### Helm Upgrade with Install

Using `upgrade --install` to handle both initial deployment and updates:

```yaml
- name: Deploy or Update Application
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-eks-cluster
    region: us-west-2
    args: |
      helm upgrade --install my-app bitnami/wordpress \
        --namespace production \
        --create-namespace \
        --wait \
        --timeout 10m
```

## Helm Repository Management

### Adding Multiple Repositories

```yaml
- name: Setup Helm Repositories
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-eks-cluster
    region: us-west-2
    args: |
      # Add multiple Helm repositories
      helm repo add bitnami https://charts.bitnami.com/bitnami
      helm repo add stable https://charts.helm.sh/stable
      helm repo add prometheus https://prometheus-community.github.io/helm-charts
      helm repo add grafana https://grafana.github.io/helm-charts
      
      # Update all repositories
      helm repo update
      
      # List available repositories
      helm repo list
```

### Searching and Installing Charts

```yaml
- name: Search and Deploy Chart
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-eks-cluster
    region: us-west-2
    args: |
      # Search for available Redis charts
      helm search repo redis
      
      # Install specific version
      helm install my-redis bitnami/redis \
        --version 17.3.14 \
        --namespace cache \
        --create-namespace
```

## Deploying from Different Sources

### Deploy from Local Chart

First, checkout your repository:

```yaml
- name: Checkout Repository
  uses: actions/checkout@v4

- name: Deploy Local Chart
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-eks-cluster
    region: us-west-2
    args: |
      # Deploy from local chart directory
      helm upgrade --install my-app ./charts/my-application \
        --namespace default \
        --values ./charts/my-application/values.yaml \
        --set image.tag=${{ github.sha }}
```

### Deploy from Git Repository

```yaml
- name: Deploy from Git
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-eks-cluster
    region: us-west-2
    args: |
      # Add git repository as Helm repo
      helm repo add my-charts git+https://github.com/myorg/helm-charts@charts
      helm repo update
      
      # Deploy from git repository
      helm upgrade --install my-app my-charts/application \
        --namespace production \
        --create-namespace
```

### Deploy from S3 Bucket

```yaml
- name: Deploy from S3
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-eks-cluster
    region: us-west-2
    args: |
      # Install S3 plugin if not already installed
      helm plugin install https://github.com/hypnoglow/helm-s3.git || true
      
      # Add S3 repository
      helm repo add my-s3-charts s3://my-helm-charts-bucket/charts
      helm repo update
      
      # Deploy from S3
      helm upgrade --install my-app my-s3-charts/application
```

## Environment-Specific Deployments

### Development Environment

```yaml
name: Deploy to Development
on:
  push:
    branches: [develop]

jobs:
  deploy-dev:
    runs-on: ubuntu-latest
    environment: development
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.DEV_AWS_ROLE_ARN }}
          aws-region: us-west-2

      - name: Deploy to Dev EKS
        uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
        with:
          cluster-name: dev-eks-cluster
          region: us-west-2
          args: |
            helm upgrade --install my-app ./charts/my-app \
              --namespace development \
              --create-namespace \
              --values ./charts/my-app/values.yaml \
              --values ./charts/my-app/values-dev.yaml \
              --set environment=development \
              --set image.tag=${{ github.sha }} \
              --set replicaCount=1 \
              --set resources.requests.memory=256Mi \
              --set resources.requests.cpu=100m
```

### Production Environment

```yaml
name: Deploy to Production
on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  deploy-prod:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.PROD_AWS_ROLE_ARN }}
          aws-region: us-west-2

      - name: Deploy to Production EKS
        uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
        with:
          cluster-name: prod-eks-cluster
          region: us-west-2
          timeout: 900  # 15 minutes for production
          args: |
            # Production deployment with extra safety
            helm upgrade --install my-app ./charts/my-app \
              --namespace production \
              --create-namespace \
              --values ./charts/my-app/values.yaml \
              --values ./charts/my-app/values-prod.yaml \
              --set environment=production \
              --set image.tag=${{ github.ref_name }} \
              --set replicaCount=3 \
              --set autoscaling.enabled=true \
              --set autoscaling.minReplicas=3 \
              --set autoscaling.maxReplicas=10 \
              --wait \
              --atomic \
              --timeout 15m
```

## Using Values Files

### Multiple Values Files

```yaml
- name: Deploy with Multiple Values
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-eks-cluster
    region: us-west-2
    args: |
      helm upgrade --install my-app ./charts/my-app \
        --namespace default \
        --values ./charts/my-app/values.yaml \
        --values ./environments/production/values.yaml \
        --values ./environments/production/secrets.yaml
```

### Dynamic Values Generation

```yaml
- name: Generate Values
  run: |
    cat > dynamic-values.yaml <<EOF
    image:
      repository: myapp
      tag: ${GITHUB_SHA}
    ingress:
      enabled: true
      hosts:
        - host: ${GITHUB_REF_NAME}.example.com
          paths:
            - path: /
              pathType: Prefix
    timestamp: $(date +%s)
    EOF

- name: Deploy with Dynamic Values
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-eks-cluster
    region: us-west-2
    args: |
      helm upgrade --install my-app ./charts/my-app \
        --values dynamic-values.yaml
```

### Using Set Commands

```yaml
- name: Deploy with Set Values
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-eks-cluster
    region: us-west-2
    args: |
      helm upgrade --install my-app bitnami/wordpress \
        --set wordpressUsername=admin \
        --set wordpressPassword=${{ secrets.WORDPRESS_PASSWORD }} \
        --set mariadb.auth.rootPassword=${{ secrets.DB_ROOT_PASSWORD }} \
        --set service.type=LoadBalancer \
        --set ingress.enabled=true \
        --set ingress.hostname=blog.example.com
```

## Rollback and History

### View Deployment History

```yaml
- name: Check Deployment History
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-eks-cluster
    region: us-west-2
    args: |
      # List all releases
      helm list --all-namespaces
      
      # Get history of specific release
      helm history my-app -n production
      
      # Get current values
      helm get values my-app -n production
```

### Rollback to Previous Version

```yaml
- name: Rollback Deployment
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-eks-cluster
    region: us-west-2
    args: |
      # Rollback to previous version
      helm rollback my-app -n production
      
      # Or rollback to specific revision
      helm rollback my-app 3 -n production
```

### Conditional Rollback on Failure

```yaml
- name: Deploy with Auto-Rollback
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-eks-cluster
    region: us-west-2
    args: |
      # Deploy with atomic flag for auto-rollback
      helm upgrade --install my-app ./charts/my-app \
        --namespace production \
        --atomic \
        --cleanup-on-fail \
        --wait \
        --timeout 10m || {
          echo "Deployment failed, checking previous version..."
          helm rollback my-app -n production
          exit 1
      }
```

## Namespace Management

### Deploy to Multiple Namespaces

```yaml
- name: Deploy Microservices
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-eks-cluster
    region: us-west-2
    args: |
      # Create namespaces if they don't exist
      kubectl create namespace frontend --dry-run=client -o yaml | kubectl apply -f -
      kubectl create namespace backend --dry-run=client -o yaml | kubectl apply -f -
      kubectl create namespace database --dry-run=client -o yaml | kubectl apply -f -
      
      # Deploy frontend
      helm upgrade --install frontend ./charts/frontend \
        --namespace frontend \
        --set service.type=LoadBalancer
      
      # Deploy backend
      helm upgrade --install backend ./charts/backend \
        --namespace backend \
        --set database.host=postgres.database.svc.cluster.local
      
      # Deploy database
      helm upgrade --install postgres bitnami/postgresql \
        --namespace database \
        --set auth.postgresPassword=${{ secrets.DB_PASSWORD }}
```

### Namespace-Specific Configuration

```yaml
- name: Configure and Deploy
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-eks-cluster
    region: us-west-2
    args: |
      # Label namespace
      kubectl label namespace production environment=prod --overwrite
      kubectl label namespace production team=platform --overwrite
      
      # Apply resource quotas
      kubectl apply -f - <<EOF
      apiVersion: v1
      kind: ResourceQuota
      metadata:
        name: production-quota
        namespace: production
      spec:
        hard:
          requests.cpu: "100"
          requests.memory: 100Gi
          persistentvolumeclaims: "10"
      EOF
      
      # Deploy application
      helm upgrade --install my-app ./charts/my-app \
        --namespace production
```

## Common Patterns

### Blue-Green Deployment

```yaml
- name: Blue-Green Deployment
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-eks-cluster
    region: us-west-2
    args: |
      # Deploy to green environment
      helm upgrade --install my-app-green ./charts/my-app \
        --namespace production \
        --set version=green \
        --set image.tag=${{ github.sha }} \
        --wait
      
      # Test green deployment
      kubectl run test-pod --rm -i --restart=Never --image=curlimages/curl -- \
        curl -f http://my-app-green.production.svc.cluster.local/health || exit 1
      
      # Switch traffic to green
      kubectl patch service my-app -n production -p '
        {
          "spec": {
            "selector": {
              "version": "green"
            }
          }
        }'
      
      # Delete old blue deployment after successful switch
      helm uninstall my-app-blue -n production || true
```

### Canary Deployment

```yaml
- name: Canary Deployment
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-eks-cluster
    region: us-west-2
    args: |
      # Deploy canary version (10% traffic)
      helm upgrade --install my-app-canary ./charts/my-app \
        --namespace production \
        --set replicaCount=1 \
        --set version=canary \
        --set image.tag=${{ github.sha }} \
        --wait
      
      # Update main deployment to reduce replicas
      CURRENT_REPLICAS=$(kubectl get deployment my-app -n production -o jsonpath='{.spec.replicas}')
      NEW_REPLICAS=$((CURRENT_REPLICAS * 9 / 10))
      
      kubectl scale deployment my-app --replicas=$NEW_REPLICAS -n production
      
      # Monitor canary for issues (simplified example)
      sleep 300  # Wait 5 minutes
      
      # If successful, promote canary
      helm upgrade --install my-app ./charts/my-app \
        --namespace production \
        --reuse-values \
        --set image.tag=${{ github.sha }} \
        --wait
      
      # Remove canary
      helm uninstall my-app-canary -n production
```

### Multi-Region Deployment

```yaml
name: Multi-Region Deployment
on:
  push:
    branches: [main]

jobs:
  deploy:
    strategy:
      matrix:
        region: [us-west-2, eu-west-1, ap-southeast-1]
        include:
          - region: us-west-2
            cluster: us-west-cluster
          - region: eu-west-1
            cluster: eu-west-cluster
          - region: ap-southeast-1
            cluster: ap-southeast-cluster
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ matrix.region }}

      - name: Deploy to ${{ matrix.region }}
        uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
        with:
          cluster-name: ${{ matrix.cluster }}
          region: ${{ matrix.region }}
          args: |
            helm upgrade --install my-app ./charts/my-app \
              --namespace production \
              --create-namespace \
              --set region=${{ matrix.region }} \
              --set image.tag=${{ github.sha }} \
              --wait
```

### Dependency Management

```yaml
- name: Deploy with Dependencies
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-eks-cluster
    region: us-west-2
    args: |
      # Update dependencies
      cd ./charts/my-app
      helm dependency update
      cd ../..
      
      # Deploy with dependencies
      helm upgrade --install my-app ./charts/my-app \
        --namespace production \
        --create-namespace \
        --wait
      
      # Verify all dependencies are running
      helm list -n production
      kubectl get pods -n production
```

### Post-Deployment Validation

```yaml
- name: Deploy and Validate
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-eks-cluster
    region: us-west-2
    args: |
      # Deploy application
      helm upgrade --install my-app ./charts/my-app \
        --namespace production \
        --wait \
        --timeout 10m
      
      # Wait for rollout to complete
      kubectl rollout status deployment/my-app -n production
      
      # Check pod status
      kubectl get pods -n production -l app=my-app
      
      # Run health checks
      kubectl exec -n production deployment/my-app -- wget -qO- http://localhost:8080/health
      
      # Check service endpoints
      kubectl get endpoints my-app -n production
      
      # Display logs from the last 5 minutes
      kubectl logs -n production -l app=my-app --since=5m
```

## Debugging and Troubleshooting

### Enable Debug Mode

```yaml
- name: Deploy with Debug Mode
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-eks-cluster
    region: us-west-2
    debug: true  # Enable debug logging
    args: |
      # Helm debug mode
      helm upgrade --install my-app ./charts/my-app \
        --namespace production \
        --debug \
        --dry-run
      
      # If dry-run succeeds, deploy for real
      helm upgrade --install my-app ./charts/my-app \
        --namespace production \
        --debug
```

### Dry Run Deployment

```yaml
- name: Test Deployment (Dry Run)
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-eks-cluster
    region: us-west-2
    dry-run: true  # Action dry-run mode
    args: |
      # This will show what would be executed without doing it
      helm upgrade --install my-app ./charts/my-app \
        --namespace production \
        --create-namespace
```

## Advanced Examples

### Using Helm Hooks

```yaml
- name: Deploy with Hooks
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-eks-cluster
    region: us-west-2
    args: |
      # Deploy with hooks for database migration
      helm upgrade --install my-app ./charts/my-app \
        --namespace production \
        --set hooks.preMigrate.enabled=true \
        --set hooks.postDeploy.enabled=true \
        --wait \
        --timeout 15m
```

### Helm Template Testing

```yaml
- name: Test and Deploy
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-eks-cluster
    region: us-west-2
    args: |
      # Lint the chart
      helm lint ./charts/my-app
      
      # Template and validate
      helm template my-app ./charts/my-app \
        --namespace production \
        --validate
      
      # If validation passes, deploy
      helm upgrade --install my-app ./charts/my-app \
        --namespace production \
        --wait
```

### Using Helm Plugins

```yaml
- name: Deploy with Plugins
  uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
  with:
    cluster-name: my-eks-cluster
    region: us-west-2
    args: |
      # Install helm-diff plugin for better diffs
      helm plugin install https://github.com/databus23/helm-diff || true
      
      # Show what would change
      helm diff upgrade my-app ./charts/my-app \
        --namespace production \
        --values values-prod.yaml
      
      # Deploy if changes look good
      helm upgrade --install my-app ./charts/my-app \
        --namespace production \
        --values values-prod.yaml
```

## CI/CD Integration Examples

### Pull Request Preview Environments

```yaml
name: PR Preview Environment
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  preview:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.DEV_AWS_ROLE_ARN }}
          aws-region: us-west-2

      - name: Deploy Preview Environment
        uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
        with:
          cluster-name: dev-eks-cluster
          region: us-west-2
          args: |
            # Create preview namespace
            NAMESPACE="preview-pr-${{ github.event.pull_request.number }}"
            
            # Deploy to preview namespace
            helm upgrade --install pr-${{ github.event.pull_request.number }} ./charts/my-app \
              --namespace $NAMESPACE \
              --create-namespace \
              --set ingress.enabled=true \
              --set ingress.hosts[0].host=pr-${{ github.event.pull_request.number }}.preview.example.com \
              --set image.tag=pr-${{ github.event.pull_request.number }} \
              --wait
            
            # Output preview URL
            echo "Preview environment deployed to:"
            echo "https://pr-${{ github.event.pull_request.number }}.preview.example.com"
```

### Automated Cleanup

```yaml
name: Cleanup Preview Environments
on:
  pull_request:
    types: [closed]
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.DEV_AWS_ROLE_ARN }}
          aws-region: us-west-2

      - name: Cleanup Old Previews
        uses: open-source-srilanka/eks-helm-client-github-action@v2.0.0
        with:
          cluster-name: dev-eks-cluster
          region: us-west-2
          args: |
            # For PR close events, clean up specific PR
            if [[ "${{ github.event_name }}" == "pull_request" ]]; then
              NAMESPACE="preview-pr-${{ github.event.pull_request.number }}"
              helm uninstall pr-${{ github.event.pull_request.number }} -n $NAMESPACE || true
              kubectl delete namespace $NAMESPACE || true
            fi
            
            # For scheduled runs, clean up old preview namespaces
            if [[ "${{ github.event_name }}" == "schedule" ]]; then
              # Get namespaces older than 7 days
              kubectl get namespaces -o json | jq -r '.items[] | 
                select(.metadata.name | startswith("preview-pr-")) | 
                select(.metadata.creationTimestamp | fromdateiso8601 < (now - 604800)) | 
                .metadata.name' | while read ns; do
                  echo "Cleaning up old namespace: $ns"
                  # Extract PR number from namespace
                  PR_NUM=$(echo $ns | sed 's/preview-pr-//')
                  helm uninstall pr-$PR_NUM -n $ns || true
                  kubectl delete namespace $ns
              done
            fi
```

## Best Practices Summary

1. **Always use `--wait`** for production deployments to ensure pods are ready
2. **Use `--atomic`** for automatic rollback on failure
3. **Set appropriate timeouts** based on your application startup time
4. **Use namespaces** to separate environments
5. **Version your images** with git SHA or semantic versions
6. **Store sensitive values** in GitHub Secrets, not in repositories
7. **Use `--dry-run`** to test changes before applying
8. **Enable debug mode** when troubleshooting issues
9. **Clean up resources** when they're no longer needed
10. **Monitor deployments** with appropriate health checks

## Next Steps

- For private cluster configurations, see [Private Cluster Examples](private-cluster.md)
- For private registry setups, see [Private Registry Examples](private-registry.md)
- For advanced scenarios, see [Advanced Scenarios](advanced-scenarios.md)
- For troubleshooting help, see [Troubleshooting Guide](troubleshooting.md)

---

**Need Help?** Check our [troubleshooting guide](troubleshooting.md) or [open an issue](https://github.com/open-source-srilanka/eks-helm-client-github-action/issues)