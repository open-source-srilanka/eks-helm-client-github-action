#!/bin/bash
set -e

# This script is the entrypoint for the GitHub Action Docker container.
# It sets up the Kubeconfig for EKS access and then executes the commands passed to the action.

# Function to log errors
log_error() {
    echo "❌ ERROR: $1" >&2
}

# Function to log info
log_info() {
    echo "ℹ️  INFO: $1"
}

# Function to log success
log_success() {
    echo "✅ SUCCESS: $1"
}

echo "--- Pre-flight Checks ---"

# Check if required environment variables are set
log_info "Checking required environment variables..."

if [ -z "$REGION_CODE" ]; then
    log_error "REGION_CODE environment variable is not set"
    exit 1
fi

if [ -z "$CLUSTER_NAME" ]; then
    log_error "CLUSTER_NAME environment variable is not set"
    exit 1
fi

log_success "Required environment variables are set"
log_info "Region: $REGION_CODE"
log_info "Cluster: $CLUSTER_NAME"

# Check AWS credentials
log_info "Checking AWS credentials..."

if [ -z "$AWS_ACCESS_KEY_ID" ] && [ -z "$AWS_PROFILE" ] && [ ! -f ~/.aws/credentials ]; then
    log_error "AWS credentials not found. Please set AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or configure AWS_PROFILE"
    exit 1
fi

# Test AWS credentials by calling STS get-caller-identity
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    log_error "AWS credentials are invalid or insufficient permissions"
    log_error "Please ensure your AWS credentials have EKS access permissions"
    exit 1
fi

log_success "AWS credentials are valid"

# Check if AWS CLI can access the EKS cluster
log_info "Checking EKS cluster accessibility..."

if ! aws eks describe-cluster --region "$REGION_CODE" --name "$CLUSTER_NAME" > /dev/null 2>&1; then
    log_error "Cannot access EKS cluster '$CLUSTER_NAME' in region '$REGION_CODE'"
    log_error "Please check:"
    log_error "  - Cluster name is correct"
    log_error "  - Region is correct"
    log_error "  - AWS credentials have EKS permissions"
    log_error "  - Cluster exists and is accessible"
    exit 1
fi

log_success "EKS cluster is accessible"

echo "--- Configuring AWS EKS Kubeconfig ---"

# Export CA_CERT: Fetches the certificate authority data for the EKS cluster.
log_info "Retrieving EKS cluster certificate authority data..."
export CA_CERT=$(aws eks describe-cluster --region "$REGION_CODE" --name "$CLUSTER_NAME" --query "cluster.certificateAuthority.data" --output text 2>/dev/null)
if [ -z "$CA_CERT" ] || [ "$CA_CERT" = "None" ]; then
    log_error "Could not retrieve EKS cluster certificate authority data"
    log_error "This might indicate insufficient permissions or cluster configuration issues"
    exit 1
fi

# Export ENDPOINT_URL: Fetches the endpoint URL for the EKS cluster.
log_info "Retrieving EKS cluster endpoint URL..."
export ENDPOINT_URL=$(aws eks describe-cluster --region "$REGION_CODE" --name "$CLUSTER_NAME" --query "cluster.endpoint" --output text 2>/dev/null)
if [ -z "$ENDPOINT_URL" ] || [ "$ENDPOINT_URL" = "None" ]; then
    log_error "Could not retrieve EKS cluster endpoint URL"
    log_error "This might indicate insufficient permissions or cluster configuration issues"
    exit 1
fi

log_success "Retrieved EKS cluster configuration"
log_info "EKS Cluster Endpoint: $ENDPOINT_URL"

# Generate Kubernetes configuration file (/opt/kubernetes/config)
log_info "Generating Kubernetes configuration file..."
if ! cat /config.template | envsubst > /opt/kubernetes/config; then
    log_error "Failed to generate Kubernetes configuration file"
    exit 1
fi

# Verify the generated Kubeconfig
if [ ! -f /opt/kubernetes/config ]; then
    log_error "Kubernetes configuration file was not created"
    exit 1
fi

log_success "Kubernetes configuration file generated successfully"

# Ensure KUBECONFIG environment variable is correctly set for subsequent commands
export KUBECONFIG=/opt/kubernetes/config

# Test kubectl connectivity
log_info "Testing kubectl connectivity to EKS cluster..."
if ! kubectl cluster-info --request-timeout=10s > /dev/null 2>&1; then
    log_error "Cannot connect to Kubernetes cluster"
    log_error "Please check:"
    log_error "  - EKS cluster is running"
    log_error "  - AWS credentials have kubernetes access permissions"
    log_error "  - Network connectivity to the cluster"
    exit 1
fi

log_success "Successfully connected to Kubernetes cluster"

# Check for Helm registry credentials if any helm registry login commands are present
log_info "Checking for Helm registry credentials..."
helm_login_required=false
for cmd in "$@"; do
    if echo "$cmd" | grep -q "helm registry login"; then
        helm_login_required=true
        break
    fi
done

if [ "$helm_login_required" = true ]; then
    log_info "Helm registry login detected in commands"
    
    # Extract registry from the command to provide better error messages
    for cmd in "$@"; do
        if echo "$cmd" | grep -q "helm registry login"; then
            registry=$(echo "$cmd" | grep -o "helm registry login [^ ]*" | cut -d' ' -f4)
            log_info "Will attempt to login to registry: $registry"
            
            # Check if credentials are available (this is a basic check)
            if echo "$cmd" | grep -q "\$.*USERNAME" && echo "$cmd" | grep -q "\$.*PASSWORD"; then
                log_info "Registry credentials will be read from environment variables"
                # Note: We can't validate the actual values here as they're in variables
            else
                log_error "Helm registry login command found but credentials format is unclear"
                log_error "Expected format: helm registry login <registry> --username \$USERNAME --password \$PASSWORD"
            fi
        fi
    done
fi

echo "--- Executing Commands ---"

# Execute each argument as a separate command
# This allows passing multiple commands line by line
command_count=0
for cmd in "$@"; do
    command_count=$((command_count + 1))
    log_info "Executing command $command_count: $cmd"
    
    # Execute the command and capture both stdout and stderr
    if eval "$cmd"; then
        log_success "Command $command_count completed successfully"
    else
        exit_code=$?
        log_error "Command $command_count failed with exit code $exit_code"
        log_error "Failed command: $cmd"
        
        # Provide specific error guidance based on command type
        if echo "$cmd" | grep -q "helm registry login"; then
            log_error "Helm registry login failed. Please check:"
            log_error "  - Registry URL is correct and accessible"
            log_error "  - Username and password environment variables are set correctly"
            log_error "  - Network connectivity to the registry"
        elif echo "$cmd" | grep -q "helm install"; then
            log_error "Helm install failed. Please check:"
            log_error "  - Chart name and version are correct"
            log_error "  - Namespace exists or --create-namespace is used"
            log_error "  - Sufficient permissions in the cluster"
            log_error "  - Chart repository is accessible"
        elif echo "$cmd" | grep -q "helm uninstall"; then
            log_error "Helm uninstall failed. Please check:"
            log_error "  - Release name exists in the specified namespace"
            log_error "  - Sufficient permissions to delete resources"
        elif echo "$cmd" | grep -q "kubectl"; then
            log_error "Kubectl command failed. Please check:"
            log_error "  - Kubernetes cluster connectivity"
            log_error "  - Sufficient permissions for the operation"
            log_error "  - Resource names and namespaces are correct"
        fi
        
        exit $exit_code
    fi
    
    # Add a small delay between commands for better logging readability
    sleep 1
done

log_success "All commands completed successfully!"
echo "--- Execution Summary ---"
log_info "Total commands executed: $command_count"
log_success "All operations completed without errors"