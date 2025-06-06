#!/bin/bash
set -e

# Enable debug mode if requested
if [[ "${INPUT_DEBUG}" == "true" ]]; then
    set -x
    export HELM_DEBUG="true"
fi

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

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Set default values from inputs or environment variables
CLUSTER_NAME="${INPUT_CLUSTER_NAME:-${CLUSTER_NAME}}"
REGION_CODE="${INPUT_REGION:-${REGION_CODE}}"
PRIVATE_CLUSTER="${INPUT_PRIVATE_CLUSTER:-false}"
HELM_REGISTRY_URL="${INPUT_HELM_REGISTRY_URL}"
HELM_REGISTRY_USERNAME="${INPUT_HELM_REGISTRY_USERNAME}"
HELM_REGISTRY_PASSWORD="${INPUT_HELM_REGISTRY_PASSWORD}"
HELM_REGISTRY_INSECURE="${INPUT_HELM_REGISTRY_INSECURE:-false}"
KUBECTL_VERSION="${INPUT_KUBECTL_VERSION:-1.28.4}"
HELM_VERSION="${INPUT_HELM_VERSION:-3.13.3}"
TIMEOUT="${INPUT_TIMEOUT:-300}"
KUBECONFIG_PATH="${INPUT_KUBECONFIG_PATH:-/opt/kubernetes/config}"
DRY_RUN="${INPUT_DRY_RUN:-false}"

log_info "Starting EKS Helm Client v2.0.0"
log_info "Cluster: ${CLUSTER_NAME}, Region: ${REGION_CODE}, Private: ${PRIVATE_CLUSTER}"

# Validate required parameters
if [[ -z "${CLUSTER_NAME}" ]]; then
    log_error "CLUSTER_NAME is required"
    log_error "Please provide either:"
    log_error "  - Input parameter: cluster-name"
    log_error "  - Environment variable: CLUSTER_NAME"
    exit 1
fi

if [[ -z "${REGION_CODE}" ]]; then
    log_error "REGION_CODE is required"
    log_error "Please provide either:"
    log_error "  - Input parameter: region"
    log_error "  - Environment variable: REGION_CODE"
    exit 1
fi

# Install specific versions if different from default
if [[ "${KUBECTL_VERSION}" != "1.28.4" ]]; then
    log_info "Installing kubectl version ${KUBECTL_VERSION}"
    curl -s -L "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl
    chmod +x /usr/local/bin/kubectl
fi

if [[ "${HELM_VERSION}" != "3.13.3" ]]; then
    log_info "Installing Helm version ${HELM_VERSION}"
    curl -s -L "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" | tar -xzO linux-amd64/helm > /usr/local/bin/helm
    chmod +x /usr/local/bin/helm
fi

# Set custom kubeconfig path
export KUBECONFIG="${KUBECONFIG_PATH}"

# Function to test network connectivity
test_connectivity() {
    local endpoint=$1
    local port=${2:-443}
    log_info "Testing connectivity to ${endpoint}:${port}"
    
    if timeout 10 nc -z "${endpoint}" "${port}" 2>/dev/null; then
        log_success "Connectivity test passed for ${endpoint}:${port}"
        return 0
    else
        log_warn "Connectivity test failed for ${endpoint}:${port}"
        return 1
    fi
}

# Function to configure EKS cluster access
configure_eks_access() {
    log_info "Configuring EKS cluster access"
    
    # Get cluster information
    log_info "Retrieving cluster information from AWS EKS API"
    
    CA_CERT=$(aws eks describe-cluster --region "${REGION_CODE}" --name "${CLUSTER_NAME}" --query "cluster.certificateAuthority.data" --output text 2>/dev/null)
    if [[ $? -ne 0 || -z "${CA_CERT}" ]]; then
        log_error "Failed to retrieve certificate authority data for cluster ${CLUSTER_NAME}"
        log_error "Please verify:"
        log_error "  - AWS credentials are configured correctly"
        log_error "  - Cluster name '${CLUSTER_NAME}' exists in region '${REGION_CODE}'"
        log_error "  - IAM permissions include eks:DescribeCluster"
        exit 1
    fi
    
    ENDPOINT_URL=$(aws eks describe-cluster --region "${REGION_CODE}" --name "${CLUSTER_NAME}" --query "cluster.endpoint" --output text 2>/dev/null)
    if [[ $? -ne 0 || -z "${ENDPOINT_URL}" ]]; then
        log_error "Failed to retrieve endpoint URL for cluster ${CLUSTER_NAME}"
        exit 1
    fi
    
    log_info "Cluster endpoint: ${ENDPOINT_URL}"
    
    # Extract hostname from endpoint for connectivity test
    ENDPOINT_HOST=$(echo "${ENDPOINT_URL}" | sed 's|https://||' | sed 's|/.*||')
    
    # Test connectivity to EKS API endpoint
    if [[ "${PRIVATE_CLUSTER}" == "true" ]]; then
        log_warn "Private cluster detected. Ensure runner has network access to EKS API endpoint"
        if ! test_connectivity "${ENDPOINT_HOST}" 443; then
            log_error "Cannot reach private EKS cluster endpoint. Ensure:"
            log_error "1. GitHub runner is in the same VPC or has VPC connectivity"
            log_error "2. Security groups allow access to EKS API endpoint"
            log_error "3. VPC endpoints are configured if needed"
            exit 1
        fi
    else
        test_connectivity "${ENDPOINT_HOST}" 443 || log_warn "Public endpoint connectivity test failed, but continuing..."
    fi
    
    # Generate kubeconfig
    log_info "Generating kubeconfig file"
    export CA_CERT ENDPOINT_URL REGION_CODE CLUSTER_NAME
    
    if [[ "${PRIVATE_CLUSTER}" == "true" && -f "/private-config.template" ]]; then
        cat /private-config.template | envsubst > "${KUBECONFIG}"
    else
        cat /config.template | envsubst > "${KUBECONFIG}"
    fi
    
    # Verify kubeconfig works
    log_info "Testing cluster connectivity"
    if timeout "${TIMEOUT}" kubectl cluster-info --request-timeout=30s >/dev/null 2>&1; then
        log_success "Successfully connected to EKS cluster"
    else
        log_error "Failed to connect to EKS cluster. Check your AWS credentials and cluster access"
        log_error "Try running with debug: true for more detailed logs"
        exit 1
    fi
}

# Function to configure private Helm registry
configure_helm_registry() {
    if [[ -n "${HELM_REGISTRY_URL}" ]]; then
        log_info "Configuring private Helm registry: ${HELM_REGISTRY_URL}"
        
        # Prepare helm repo add command
        HELM_REPO_CMD="helm repo add private-registry '${HELM_REGISTRY_URL}'"
        
        if [[ -n "${HELM_REGISTRY_USERNAME}" && -n "${HELM_REGISTRY_PASSWORD}" ]]; then
            HELM_REPO_CMD="${HELM_REPO_CMD} --username '${HELM_REGISTRY_USERNAME}' --password '${HELM_REGISTRY_PASSWORD}'"
        fi
        
        if [[ "${HELM_REGISTRY_INSECURE}" == "true" ]]; then
            HELM_REPO_CMD="${HELM_REPO_CMD} --insecure-skip-tls-verify"
            log_warn "Using insecure connection to Helm registry"
        fi
        
        # Add private registry
        if eval "${HELM_REPO_CMD}"; then
            log_success "Private Helm registry added successfully"
            helm repo update
        else
            log_error "Failed to add private Helm registry"
            log_error "Please verify:"
            log_error "  - Registry URL is correct: ${HELM_REGISTRY_URL}"
            log_error "  - Credentials are valid"
            log_error "  - Network connectivity to registry"
            exit 1
        fi
    fi
}

# Function to verify Helm installation
verify_helm() {
    log_info "Verifying Helm installation"
    if helm version --short; then
        log_success "Helm is working correctly"
    else
        log_error "Helm verification failed"
        exit 1
    fi
}

# Function to display tool versions
display_versions() {
    log_info "Tool versions:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    kubectl version --client --short 2>/dev/null || echo "kubectl: version check failed"
    helm version --short 2>/dev/null || echo "Helm: version check failed"
    aws --version 2>/dev/null || echo "AWS CLI: version check failed"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Function to validate environment
validate_environment() {
    log_info "Validating environment"
    
    # Check required commands
    local required_commands=("kubectl" "helm" "aws" "envsubst")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Required command not found: $cmd"
            exit 1
        fi
    done
    
    # Check AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS credentials not configured or invalid"
        log_error "Please ensure AWS credentials are properly set up"
        exit 1
    fi
    
    log_success "Environment validation passed"
}

# Function for cleanup on exit
cleanup() {
    log_info "Cleaning up sensitive data..."
    
    # Remove kubeconfig
    if [[ -f "${KUBECONFIG}" ]]; then
        rm -f "${KUBECONFIG}" 2>/dev/null || true
    fi
    
    # Clear sensitive environment variables
    unset HELM_REGISTRY_PASSWORD 2>/dev/null || true
    unset AWS_SECRET_ACCESS_KEY 2>/dev/null || true
    unset AWS_SESSION_TOKEN 2>/dev/null || true
    
    # Clear Helm repository credentials
    if [[ -f "/opt/helm/repositories.yaml" ]]; then
        rm -f "/opt/helm/repositories.yaml" 2>/dev/null || true
    fi
    
    log_info "Cleanup completed"
}

# Function for enhanced error handling
handle_error() {
    local exit_code=$?
    local line_number=$1
    
    log_error "Script failed at line ${line_number} with exit code ${exit_code}"
    
    if [[ "${INPUT_DEBUG}" == "true" ]]; then
        log_info "Debug information:"
        echo "  - Cluster: ${CLUSTER_NAME}"
        echo "  - Region: ${REGION_CODE}"
        echo "  - Private cluster: ${PRIVATE_CLUSTER}"
        echo "  - Helm registry: ${HELM_REGISTRY_URL:-"none"}"
        echo "  - kubectl version: ${KUBECTL_VERSION}"
        echo "  - Helm version: ${HELM_VERSION}"
    fi
    
    cleanup
    exit $exit_code
}

# Set up error handling
trap 'handle_error ${LINENO}' ERR
trap cleanup EXIT

# Main execution
main() {
    log_info "=== EKS Helm Client v2.0.0 ==="
    
    # Display versions if debug enabled
    if [[ "${INPUT_DEBUG}" == "true" ]]; then
        display_versions
    fi
    
    # Validate environment
    validate_environment
    
    # Configure EKS access
    configure_eks_access
    
    # Configure private Helm registry if provided
    configure_helm_registry
    
    # Verify Helm
    verify_helm
    
    # Execute user commands
    log_info "Executing user commands"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_warn "DRY RUN MODE: Commands will be displayed but not executed"
        echo "Commands to execute:"
        echo "${@}"
        log_success "Dry run completed successfully"
    else
        # Set timeout for kubectl operations
        export KUBECTL_TIMEOUT="${TIMEOUT}s"
        
        # Execute the provided arguments
        log_info "Running: $*"
        timeout "${TIMEOUT}" bash -c "$*"
        
        if [[ $? -eq 0 ]]; then
            log_success "Commands executed successfully"
        else
            log_error "Command execution failed"
            exit 1
        fi
    fi
    
    log_success "EKS Helm Client execution completed"
}

# Validate that we have arguments to execute
if [[ $# -eq 0 ]]; then
    log_error "No commands provided to execute"
    log_error "Please provide commands in the 'args' parameter"
    exit 1
fi

# Run main function with all arguments
main "$@"