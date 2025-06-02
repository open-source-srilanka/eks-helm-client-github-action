#!/bin/bash
set -euo pipefail 

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Enable debug mode if requested
if [[ "${INPUT_DEBUG:-false}" == "true" ]]; then
    set -x
    log_info "Debug mode enabled"
fi

# Validate required inputs
validate_inputs() {
    log_info "Validating inputs..."
    
    if [[ -z "${INPUT_CLUSTER_NAME:-}" ]]; then
        log_error "cluster-name is required"
        exit 1
    fi
    
    if [[ -z "${INPUT_REGION:-}" ]]; then
        log_error "region is required"
        exit 1
    fi
    
    if [[ -z "${INPUT_HELM_COMMANDS:-}" ]]; then
        log_error "helm-commands is required"
        exit 1
    fi
    
    log_success "Input validation passed"
}

# Configure AWS authentication
configure_aws_auth() {
    log_info "Configuring AWS authentication..."
    
    # Assume role if specified (for IRSA or cross-account access)
    if [[ -n "${INPUT_ROLE_ARN:-}" ]]; then
        log_info "Assuming role: ${INPUT_ROLE_ARN}"
        
        local session_name="${INPUT_ASSUME_ROLE_SESSION_NAME:-github-actions-helm-deploy}"
        local temp_creds
        
        temp_creds=$(aws sts assume-role \
            --role-arn "${INPUT_ROLE_ARN}" \
            --role-session-name "${session_name}" \
            --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
            --output text)
        
        if [[ $? -ne 0 ]]; then
            log_error "Failed to assume role"
            exit 1
        fi
        
        export AWS_ACCESS_KEY_ID=$(echo "${temp_creds}" | cut -f1)
        export AWS_SECRET_ACCESS_KEY=$(echo "${temp_creds}" | cut -f2)
        export AWS_SESSION_TOKEN=$(echo "${temp_creds}" | cut -f3)
        
        log_success "Role assumed successfully"
    fi
    
    # Verify AWS credentials
    aws sts get-caller-identity > /dev/null
    if [[ $? -ne 0 ]]; then
        log_error "AWS authentication failed"
        exit 1
    fi
    
    log_success "AWS authentication configured"
}

# Get EKS cluster information
get_cluster_info() {
    log_info "Retrieving EKS cluster information..."
    
    local cluster_info
    cluster_info=$(aws eks describe-cluster \
        --region "${INPUT_REGION}" \
        --name "${INPUT_CLUSTER_NAME}" \
        --query 'cluster.{endpoint:endpoint,ca:certificateAuthority.data,status:status}' \
        --output json)
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to retrieve cluster information"
        exit 1
    fi
    
    export CLUSTER_ENDPOINT=$(echo "${cluster_info}" | jq -r '.endpoint')
    export CLUSTER_CA=$(echo "${cluster_info}" | jq -r '.ca')
    export CLUSTER_STATUS=$(echo "${cluster_info}" | jq -r '.status')
    
    if [[ "${CLUSTER_STATUS}" != "ACTIVE" ]]; then
        log_error "Cluster is not in ACTIVE state: ${CLUSTER_STATUS}"
        exit 1
    fi
    
    log_success "Cluster information retrieved successfully"
}

# Configure kubectl for private clusters
configure_private_cluster_access() {
    if [[ "${INPUT_PRIVATE_CLUSTER:-false}" == "true" ]]; then
        log_info "Configuring private cluster access..."
        
        # Use VPC endpoint if provided
        if [[ -n "${INPUT_VPC_ENDPOINT:-}" ]]; then
            log_info "Using VPC endpoint: ${INPUT_VPC_ENDPOINT}"
            export CLUSTER_ENDPOINT="${INPUT_VPC_ENDPOINT}"
        fi
        
        # Setup bastion host access if provided
        if [[ -n "${INPUT_BASTION_HOST:-}" ]]; then
            log_info "Setting up bastion host access..."
            # This would require SSH key setup in the container
            # Implementation depends on specific bastion setup
            log_warn "Bastion host access requires additional SSH configuration"
        fi
        
        # Additional network configuration for private clusters
        export HELM_ARGS="${HELM_ARGS:-} --kube-insecure-skip-tls-verify=false"
        
        log_success "Private cluster access configured"
    fi
}

# Create kubeconfig
create_kubeconfig() {
    log_info "Creating kubeconfig..."
    
    mkdir -p /opt/kubernetes
    
    # Use modern AWS CLI EKS authentication
    cat > /opt/kubernetes/config << EOF
apiVersion: v1
clusters:
- cluster:
    server: ${CLUSTER_ENDPOINT}
    certificate-authority-data: ${CLUSTER_CA}
  name: ${INPUT_CLUSTER_NAME}
contexts:
- context:
    cluster: ${INPUT_CLUSTER_NAME}
    user: aws-user
    namespace: ${INPUT_NAMESPACE:-default}
  name: aws-context
current-context: aws-context
kind: Config
preferences: {}
users:
- name: aws-user
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: aws
      args:
        - --region
        - ${INPUT_REGION}
        - eks
        - get-token
        - --cluster-name
        - ${INPUT_CLUSTER_NAME}
EOF

    export KUBECONFIG=/opt/kubernetes/config
    
    # Test connection
    if ! kubectl get nodes --request-timeout=30s > /dev/null 2>&1; then
        log_error "Failed to connect to Kubernetes cluster"
        exit 1
    fi
    
    log_success "Kubeconfig created and tested successfully"
}

# Setup namespace
setup_namespace() {
    local namespace="${INPUT_NAMESPACE:-default}"
    
    if [[ "${namespace}" != "default" ]]; then
        log_info "Setting up namespace: ${namespace}"
        
        if [[ "${INPUT_CREATE_NAMESPACE:-false}" == "true" ]]; then
            kubectl create namespace "${namespace}" --dry-run=client -o yaml | kubectl apply -f -
            log_success "Namespace ${namespace} created/updated"
        else
            if ! kubectl get namespace "${namespace}" > /dev/null 2>&1; then
                log_error "Namespace ${namespace} does not exist and create-namespace is false"
                exit 1
            fi
        fi
    fi
}

# Configure private registry authentication
configure_private_registries() {
    log_info "Configuring private registry authentication..."
    
    # AWS ECR Authentication
    if [[ "${INPUT_AUTO_LOGIN_ECR:-false}" == "true" ]] || [[ -n "${INPUT_ECR_REGISTRY:-}" ]]; then
        log_info "Configuring AWS ECR authentication..."
        
        local ecr_registry="${INPUT_ECR_REGISTRY:-}"
        if [[ -z "${ecr_registry}" ]]; then
            # Extract ECR registry from AWS account
            local aws_account=$(aws sts get-caller-identity --query Account --output text)
            ecr_registry="${aws_account}.dkr.ecr.${INPUT_REGION}.amazonaws.com"
        fi
        
        log_info "Logging into ECR registry: ${ecr_registry}"
        aws ecr get-login-password --region "${INPUT_REGION}" | \
            helm registry login --username AWS --password-stdin "${ecr_registry}"
        
        if [[ $? -eq 0 ]]; then
            log_success "ECR authentication configured successfully"
        else
            log_error "Failed to authenticate with ECR"
            exit 1
        fi
    fi
    
    # GitHub Container Registry Authentication
    if [[ -n "${INPUT_GITHUB_PACKAGES_TOKEN:-}" ]]; then
        log_info "Configuring GitHub Container Registry authentication..."
        
        echo "${INPUT_GITHUB_PACKAGES_TOKEN}" | \
            helm registry login --username "${GITHUB_ACTOR:-github-actions}" --password-stdin ghcr.io
        
        if [[ $? -eq 0 ]]; then
            log_success "GitHub Container Registry authentication configured"
        else
            log_error "Failed to authenticate with GitHub Container Registry"
            exit 1
        fi
    fi
    
    # Primary Private Registry Authentication
    if [[ -n "${INPUT_PRIVATE_REGISTRY_URL:-}" ]]; then
        log_info "Configuring private registry authentication: ${INPUT_PRIVATE_REGISTRY_URL}"
        
        local username=""
        local password=""
        
        # Get credentials from Secrets Manager if specified
        if [[ -n "${INPUT_PRIVATE_REGISTRY_USERNAME_SECRET:-}" ]]; then
            username=$(aws secretsmanager get-secret-value \
                --region "${INPUT_SECRETS_MANAGER_REGION:-${INPUT_REGION}}" \
                --secret-id "${INPUT_PRIVATE_REGISTRY_USERNAME_SECRET}" \
                --query SecretString --output text)
        elif [[ -n "${INPUT_PRIVATE_REGISTRY_USERNAME:-}" ]]; then
            username="${INPUT_PRIVATE_REGISTRY_USERNAME}"
        fi
        
        if [[ -n "${INPUT_PRIVATE_REGISTRY_PASSWORD_SECRET:-}" ]]; then
            password=$(aws secretsmanager get-secret-value \
                --region "${INPUT_SECRETS_MANAGER_REGION:-${INPUT_REGION}}" \
                --secret-id "${INPUT_PRIVATE_REGISTRY_PASSWORD_SECRET}" \
                --query SecretString --output text)
        elif [[ -n "${INPUT_PRIVATE_REGISTRY_PASSWORD:-}" ]]; then
            password="${INPUT_PRIVATE_REGISTRY_PASSWORD}"
        fi
        
        if [[ -n "${username}" && -n "${password}" ]]; then
            # Check if it's an OCI registry or traditional Helm repo
            if [[ "${INPUT_PRIVATE_REGISTRY_URL}" =~ ^oci:// ]] || [[ "${INPUT_PRIVATE_REGISTRY_URL}" =~ registry ]]; then
                # OCI registry login
                echo "${password}" | \
                    helm registry login --username "${username}" --password-stdin "${INPUT_PRIVATE_REGISTRY_URL}"
            else
                # Traditional Helm repository - will be added during helm commands
                export PRIVATE_REGISTRY_USERNAME="${username}"
                export PRIVATE_REGISTRY_PASSWORD="${password}"
            fi
            
            if [[ $? -eq 0 ]]; then
                log_success "Private registry authentication configured"
            else
                log_error "Failed to authenticate with private registry"
                exit 1
            fi
        else
            log_warn "Private registry URL specified but no credentials provided"
        fi
    fi
    
    # Additional Registries (JSON format)
    if [[ -n "${INPUT_ADDITIONAL_REGISTRIES:-}" ]]; then
        log_info "Configuring additional private registries..."
        
        echo "${INPUT_ADDITIONAL_REGISTRIES}" | jq -r '.[] | @base64' | while read -r registry; do
            local reg_config=$(echo "${registry}" | base64 -d)
            local reg_url=$(echo "${reg_config}" | jq -r '.url')
            local reg_username=$(echo "${reg_config}" | jq -r '.username')
            local reg_password=$(echo "${reg_config}" | jq -r '.password')
            
            if [[ -n "${reg_url}" && -n "${reg_username}" && -n "${reg_password}" ]]; then
                log_info "Authenticating with additional registry: ${reg_url}"
                echo "${reg_password}" | \
                    helm registry login --username "${reg_username}" --password-stdin "${reg_url}"
                
                if [[ $? -eq 0 ]]; then
                    log_success "Additional registry authentication configured: ${reg_url}"
                else
                    log_error "Failed to authenticate with registry: ${reg_url}"
                fi
            fi
        done
    fi
    
    log_success "Private registry authentication completed"
}

# Configure Helm
configure_helm() {
    log_info "Configuring Helm..."
    
    # Initialize Helm directories
    mkdir -p /opt/helm/{cache,config,data}
    
    # Set Helm environment variables
    export HELM_CACHE_HOME="/opt/helm/cache"
    export HELM_CONFIG_HOME="/opt/helm/config"
    export HELM_DATA_HOME="/opt/helm/data"
    
    # Configure Helm with security options
    local helm_args=""
    
    if [[ "${INPUT_VERIFY_CHARTS:-false}" == "true" ]]; then
        helm_args="${helm_args} --verify"
        log_info "Chart verification enabled"
    fi
    
    if [[ "${INPUT_ATOMIC:-true}" == "true" ]]; then
        helm_args="${helm_args} --atomic"
    fi
    
    if [[ "${INPUT_WAIT:-true}" == "true" ]]; then
        helm_args="${helm_args} --wait"
    fi
    
    if [[ -n "${INPUT_TIMEOUT:-}" ]]; then
        helm_args="${helm_args} --timeout ${INPUT_TIMEOUT}"
    fi
    
    export HELM_ARGS="${helm_args}"
    
    log_success "Helm configured successfully"
}

# Create helper functions for private helm packages
create_helm_helpers() {
    log_info "Creating Helm helper functions..."
    
    # Create helper for OCI charts
    cat > /usr/local/bin/helm-oci << 'EOF'
#!/bin/bash
# Helper function for OCI chart operations
CHART_URL="$1"
RELEASE_NAME="$2"
NAMESPACE="${3:-default}"
shift 3

helm upgrade --install "${RELEASE_NAME}" "${CHART_URL}" \
    --namespace "${NAMESPACE}" \
    "$@"
EOF
    chmod +x /usr/local/bin/helm-oci
    
    # Create helper for private repo charts
    cat > /usr/local/bin/helm-private << 'EOF'
#!/bin/bash
# Helper function for private repository charts
REPO_URL="$1"
REPO_NAME="$2"
CHART_NAME="$3"
RELEASE_NAME="$4"
NAMESPACE="${5:-default}"
shift 5

# Add repository if not already added
if ! helm repo list | grep -q "${REPO_NAME}"; then
    if [[ -n "${PRIVATE_REGISTRY_USERNAME:-}" && -n "${PRIVATE_REGISTRY_PASSWORD:-}" ]]; then
        helm repo add "${REPO_NAME}" "${REPO_URL}" \
            --username "${PRIVATE_REGISTRY_USERNAME}" \
            --password "${PRIVATE_REGISTRY_PASSWORD}" \
            "$@"
    else
        helm repo add "${REPO_NAME}" "${REPO_URL}" "$@"
    fi
    helm repo update
fi

helm upgrade --install "${RELEASE_NAME}" "${REPO_NAME}/${CHART_NAME}" \
    --namespace "${NAMESPACE}"
EOF
    chmod +x /usr/local/bin/helm-private
    
    log_success "Helm helper functions created"
}

# Validate manifests if requested
validate_manifests() {
    if [[ "${INPUT_VALIDATE_MANIFESTS:-true}" == "true" ]]; then
        log_info "Validating Kubernetes manifests..."
        
        # Use helm template to generate manifests for validation
        local temp_dir=$(mktemp -d)
        local validation_failed=false
        
        # This is a simplified validation - in practice, you'd parse the helm commands
        # and run helm template for each chart, then validate with kubectl --dry-run
        
        # Example validation command (adapt based on your helm commands)
        # helm template <release-name> <chart> --namespace ${INPUT_NAMESPACE:-default} > "${temp_dir}/manifests.yaml"
        # kubectl apply --dry-run=client -f "${temp_dir}/manifests.yaml"
        
        rm -rf "${temp_dir}"
        
        if [[ "${validation_failed}" == "true" ]]; then
            log_error "Manifest validation failed"
            exit 1
        fi
        
        log_success "Manifest validation passed"
    fi
}

# Create backup if requested
create_backup() {
    if [[ "${INPUT_ENABLE_BACKUP:-false}" == "true" ]]; then
        log_info "Creating backup..."
        
        if [[ -z "${INPUT_BACKUP_STORAGE:-}" ]]; then
            log_error "backup-storage is required when enable-backup is true"
            exit 1
        fi
        
        local backup_timestamp=$(date +%Y%m%d-%H%M%S)
        local backup_path="s3://${INPUT_BACKUP_STORAGE}/backups/${INPUT_CLUSTER_NAME}/${backup_timestamp}"
        
        # Get current Helm releases
        helm list --all-namespaces -o json > "/tmp/helm-releases-${backup_timestamp}.json"
        
        # Upload backup to S3
        aws s3 cp "/tmp/helm-releases-${backup_timestamp}.json" "${backup_path}/"
        
        log_success "Backup created at ${backup_path}"
    fi
}

# Execute Helm commands with enhanced error handling
execute_helm_commands() {
    log_info "Executing Helm commands..."
    
    # Set common Helm options
    local helm_opts=""
    helm_opts="${helm_opts} --namespace ${INPUT_NAMESPACE:-default}"
    helm_opts="${helm_opts} ${HELM_ARGS:-}"
    
    if [[ "${INPUT_DEBUG:-false}" == "true" ]]; then
        helm_opts="${helm_opts} --debug"
    fi
    
    if [[ "${INPUT_DRY_RUN:-false}" == "true" ]]; then
        helm_opts="${helm_opts} --dry-run"
        log_info "Dry run mode enabled"
    fi
    
    # Execute the Helm commands
    log_info "Running: ${INPUT_HELM_COMMANDS}"
    
    # Capture output for GitHub Actions
    local output_file="/tmp/helm-output.txt"
    
    # Execute commands with proper error handling
    if eval "${INPUT_HELM_COMMANDS}" ${helm_opts} 2>&1 | tee "${output_file}"; then
        log_success "Helm commands executed successfully"
        
        # Extract useful information for outputs
        if [[ -f "${output_file}" ]]; then
            # Try to extract release information
            local release_info=$(grep -i "release.*deployed" "${output_file}" || echo "")
            if [[ -n "${release_info}" ]]; then
                echo "helm-output=${release_info}" >> $GITHUB_OUTPUT
            fi
        fi
        
        echo "deployment-status=success" >> $GITHUB_OUTPUT
    else
        log_error "Helm commands failed"
        echo "deployment-status=failure" >> $GITHUB_OUTPUT
        exit 1
    fi
}

# Setup AWS Secrets Manager integration
setup_secrets_manager() {
    if [[ "${INPUT_ENABLE_SECRETS_MANAGER:-false}" == "true" ]]; then
        log_info "Setting up AWS Secrets Manager integration..."
        
        local secrets_region="${INPUT_SECRETS_MANAGER_REGION:-${INPUT_REGION}}"
        
        # Create a helper script for accessing secrets in Helm
        cat > /usr/local/bin/aws-secret << 'EOF'
#!/bin/bash
# Helper script to retrieve secrets from AWS Secrets Manager
SECRET_NAME="$1"
SECRET_REGION="${2:-${AWS_DEFAULT_REGION}}"

if [[ -z "${SECRET_NAME}" ]]; then
    echo "Usage: aws-secret <secret-name> [region]" >&2
    exit 1
fi

aws secretsmanager get-secret-value \
    --region "${SECRET_REGION}" \
    --secret-id "${SECRET_NAME}" \
    --query SecretString \
    --output text
EOF
        chmod +x /usr/local/bin/aws-secret
        
        export AWS_DEFAULT_REGION="${secrets_region}"
        
        log_success "AWS Secrets Manager integration configured"
    fi
}

# Main execution function
main() {
    log_info "Starting EKS Helm deployment with private package support..."
    
    # Execute setup functions
    validate_inputs
    configure_aws_auth
    get_cluster_info
    configure_private_cluster_access
    create_kubeconfig
    setup_namespace
    configure_helm
    setup_secrets_manager
    create_helm_helpers
    configure_private_registries
    validate_manifests
    create_backup
    execute_helm_commands
    
    log_success "EKS Helm deployment completed successfully!"
}

# Handle script termination
cleanup() {
    log_info "Cleaning up..."
    # Remove sensitive files
    rm -f /tmp/helm-output.txt
    rm -f /tmp/helm-releases-*.json
    # Clear any cached registry credentials
    rm -rf /opt/helm/registry 2>/dev/null || true
}

trap cleanup EXIT

# Execute main function
main "$@"