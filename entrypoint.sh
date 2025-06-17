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

# Function to check if cluster is private
check_cluster_privacy() {
    local endpoint_config
    endpoint_config=$(aws eks describe-cluster --region "$REGION_CODE" --name "$CLUSTER_NAME" --query "cluster.resourcesVpcConfig.endpointConfig" --output json 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    local public_access=$(echo "$endpoint_config" | jq -r '.publicAccess // true')
    local private_access=$(echo "$endpoint_config" | jq -r '.privateAccess // false')
    
    log_info "Cluster endpoint configuration:"
    log_info "  - Public access: $public_access"
    log_info "  - Private access: $private_access"
    
    if [ "$public_access" = "false" ] && [ "$private_access" = "true" ]; then
        log_info "Detected fully private EKS cluster"
        return 0
    elif [ "$public_access" = "true" ] && [ "$private_access" = "true" ]; then
        log_info "Detected EKS cluster with both public and private access"
        return 1
    else
        log_info "Detected public EKS cluster"
        return 1
    fi
}

# Check if we're running in a private network context
check_private_network_setup() {
    log_info "Checking private network setup..."
    
    # Check if we're running on a self-hosted runner (common for private clusters)
    if [ -n "$RUNNER_NAME" ] && [ "$RUNNER_NAME" != "GitHub Actions" ]; then
        log_info "Running on self-hosted runner: $RUNNER_NAME"
        return 0
    fi
    
    # Check if VPN environment variables are set
    if [ -n "$VPN_CONFIG" ] || [ -n "$BASTION_HOST" ]; then
        log_info "VPN or bastion configuration detected"
        return 0
    fi
    
    # Check for AWS VPC environment (like running in EC2)
    if curl -s --max-time 5 http://169.254.169.254/latest/meta-data/instance-id > /dev/null 2>&1; then
        log_info "Running in AWS environment (likely EC2 instance)"
        return 0
    fi
    
    return 1
}

# Function to test network connectivity to EKS endpoint
test_eks_connectivity() {
    local endpoint_url="$1"
    local host=$(echo "$endpoint_url" | sed 's|https://||' | sed 's|/.*||')
    
    log_info "Testing network connectivity to EKS endpoint: $host"
    
    # Test DNS resolution
    if ! nslookup "$host" > /dev/null 2>&1; then
        log_error "DNS resolution failed for $host"
        return 1
    fi
    
    # Test TCP connectivity
    if ! timeout 10 bash -c "</dev/tcp/$host/443" 2>/dev/null; then
        log_error "TCP connection failed to $host:443"
        return 1
    fi
    
    log_success "Network connectivity to EKS endpoint verified"
    return 0
}

# Function to setup bastion/proxy if configured
setup_network_proxy() {
    if [ -n "$BASTION_HOST" ] && [ -n "$BASTION_USER" ]; then
        log_info "Setting up SSH tunnel through bastion host..."
        
        # Check if SSH key is provided
        if [ -n "$SSH_PRIVATE_KEY" ]; then
            echo "$SSH_PRIVATE_KEY" > /tmp/ssh_key
            chmod 600 /tmp/ssh_key
            SSH_KEY_PARAM="-i /tmp/ssh_key"
        else
            SSH_KEY_PARAM=""
        fi
        
        # Start SSH tunnel in background
        ssh -f -N -L 8443:$CLUSTER_ENDPOINT_HOST:443 \
            $SSH_KEY_PARAM \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            $BASTION_USER@$BASTION_HOST
        
        if [ $? -eq 0 ]; then
            log_success "SSH tunnel established through bastion"
            export PROXY_ENDPOINT="https://localhost:8443"
        else
            log_error "Failed to establish SSH tunnel through bastion"
            return 1
        fi
    fi
    
    # Setup HTTP proxy if configured
    if [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ]; then
        log_info "HTTP proxy configuration detected"
        export http_proxy="$HTTP_PROXY"
        export https_proxy="$HTTPS_PROXY"
        export no_proxy="$NO_PROXY"
    fi
    
    return 0
}

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

log_success "EKS cluster is accessible via AWS API"

# Check if cluster is private and handle accordingly
if check_cluster_privacy; then
    log_info "Private EKS cluster detected - checking network setup..."
    
    if ! check_private_network_setup; then
        log_error "Private EKS cluster requires special network setup!"
        log_error "For private EKS clusters, you need one of the following:"
        log_error "  1. Self-hosted GitHub Actions runner in the same VPC"
        log_error "  2. VPN connection to the cluster's VPC"
        log_error "  3. Bastion host configuration"
        log_error "  4. GitHub Actions runner in EC2 with proper networking"
        log_error ""
        log_error "Environment variables for private cluster access:"
        log_error "  - BASTION_HOST: SSH bastion host IP/hostname"
        log_error "  - BASTION_USER: SSH username for bastion"
        log_error "  - SSH_PRIVATE_KEY: SSH private key for bastion access"
        log_error "  - HTTP_PROXY/HTTPS_PROXY: HTTP proxy settings"
        exit 1
    fi
    
    # Setup network proxy/tunnel if configured
    if ! setup_network_proxy; then
        log_error "Failed to setup network connectivity for private cluster"
        exit 1
    fi
fi

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

# Use proxy endpoint if configured
if [ -n "$PROXY_ENDPOINT" ]; then
    log_info "Using proxy endpoint for private cluster access"
    export ENDPOINT_URL="$PROXY_ENDPOINT"
fi

log_success "Retrieved EKS cluster configuration"
log_info "EKS Cluster Endpoint: $ENDPOINT_URL"

# Test network connectivity to the endpoint
export CLUSTER_ENDPOINT_HOST=$(echo "$ENDPOINT_URL" | sed 's|https://||' | sed 's|/.*||')
if ! test_eks_connectivity "$ENDPOINT_URL"; then
    log_error "Cannot establish network connectivity to EKS cluster endpoint"
    log_error "This is common with private EKS clusters. Please ensure:"
    log_error "  - You're running from within the cluster's VPC"
    log_error "  - VPN connection is established"
    log_error "  - Bastion host/proxy is properly configured"
    log_error "  - Security groups allow access on port 443"
    exit 1
fi

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

# Test kubectl connectivity with longer timeout for private clusters
log_info "Testing kubectl connectivity to EKS cluster..."
kubectl_timeout=30
if [ -n "$PROXY_ENDPOINT" ] || check_cluster_privacy; then
    kubectl_timeout=60
    log_info "Using extended timeout for private cluster connectivity test"
fi

if ! timeout $kubectl_timeout kubectl cluster-info --request-timeout=30s > /dev/null 2>&1; then
    log_error "Cannot connect to Kubernetes cluster"
    log_error "Please check:"
    log_error "  - EKS cluster is running and healthy"
    log_error "  - AWS credentials have kubernetes access permissions (eks:DescribeCluster)"
    log_error "  - Network connectivity to the cluster endpoint"
    log_error "  - Security groups allow inbound traffic on port 443"
    log_error "  - RBAC permissions for the AWS user/role"
    
    # Additional troubleshooting for private clusters
    if check_cluster_privacy 2>/dev/null; then
        log_error ""
        log_error "Private cluster specific checks:"
        log_error "  - Runner is in the same VPC as the EKS cluster"
        log_error "  - VPC has proper DNS resolution enabled"
        log_error "  - Route tables allow access to the cluster subnets"
        log_error "  - NAT Gateway/Instance for internet access (if needed)"
    fi
    
    exit 1
fi

log_success "Successfully connected to Kubernetes cluster"

# Test basic kubectl permissions
log_info "Testing basic kubectl permissions..."
if kubectl auth can-i get pods --all-namespaces > /dev/null 2>&1; then
    log_success "Basic kubectl permissions verified"
else
    log_error "Limited kubectl permissions detected"
    log_error "Some operations may fail due to RBAC restrictions"
    log_error "Ensure your AWS user/role has proper Kubernetes RBAC bindings"
fi

# Check for Helm registry credentials if any helm registry login commands are present
log_info "Checking for Helm registry credentials..."
helm_login_required=false
commands_string="$*"

if echo "$commands_string" | grep -q "helm registry login"; then
    helm_login_required=true
fi

if [ "$helm_login_required" = true ]; then
    log_info "Helm registry login detected in commands"
    
    # Extract registry from the commands to provide better error messages
    registry=$(echo "$commands_string" | grep -o "helm registry login [^ ]*" | head -1 | cut -d' ' -f4)
    if [ -n "$registry" ]; then
        log_info "Will attempt to login to registry: $registry"
    fi
    
    # Check if credentials are available (this is a basic check)
    if echo "$commands_string" | grep -q "\$.*USERNAME" && echo "$commands_string" | grep -q "\$.*PASSWORD"; then
        log_info "Registry credentials will be read from environment variables"
        # Note: We can't validate the actual values here as they're in variables
    else
        log_error "Helm registry login command found but credentials format is unclear"
        log_error "Expected format: helm registry login <registry> --username \$USERNAME --password \$PASSWORD"
    fi
fi

echo "--- Executing Commands ---"

# Join all arguments into a single string and process line by line
# This handles multi-line commands properly
commands="$*"
command_count=0

# Process commands line by line, handling line continuations
current_command=""
while IFS= read -r line || [ -n "$line" ]; do
    # Skip empty lines
    if [ -z "$(echo "$line" | xargs)" ]; then
        continue
    fi
    
    # Check if line ends with backslash (continuation)
    if [[ "$line" =~ \\[[:space:]]*$ ]]; then
        # Remove trailing backslash and whitespace, add to current command
        current_command="$current_command$(echo "$line" | sed 's/\\[[:space:]]*$//')"
        current_command="$current_command "
        continue
    else
        # Complete the command
        current_command="$current_command$line"
    fi
    
    # Execute the complete command
    if [ -n "$current_command" ]; then
        command_count=$((command_count + 1))
        log_info "Executing command $command_count: $current_command"
        
        # Execute the command and capture both stdout and stderr
        if eval "$current_command"; then
            log_success "Command $command_count completed successfully"
        else
            exit_code=$?
            log_error "Command $command_count failed with exit code $exit_code"
            log_error "Failed command: $current_command"
            
            # Provide specific error guidance based on command type
            if echo "$current_command" | grep -q "helm registry login"; then
                log_error "Helm registry login failed. Please check:"
                log_error "  - Registry URL is correct and accessible"
                log_error "  - Username and password environment variables are set correctly"
                log_error "  - Network connectivity to the registry"
            elif echo "$current_command" | grep -q "helm install"; then
                log_error "Helm install failed. Please check:"
                log_error "  - Chart name and version are correct"
                log_error "  - Namespace exists or --create-namespace is used"
                log_error "  - Sufficient permissions in the cluster"
                log_error "  - Chart repository is accessible"
            elif echo "$current_command" | grep -q "helm uninstall"; then
                log_error "Helm uninstall failed. Please check:"
                log_error "  - Release name exists in the specified namespace"
                log_error "  - Sufficient permissions to delete resources"
            elif echo "$current_command" | grep -q "kubectl"; then
                log_error "Kubectl command failed. Please check:"
                log_error "  - Kubernetes cluster connectivity"
                log_error "  - Sufficient permissions for the operation"
                log_error "  - Resource names and namespaces are correct"
            fi
            
            exit $exit_code
        fi
        
        # Reset for next command
        current_command=""
        
        # Add a small delay between commands for better logging readability
        sleep 1
    fi
done <<< "$commands"

log_success "All commands completed successfully!"
echo "--- Execution Summary ---"
log_info "Total commands executed: $command_count"
log_success "All operations completed without errors"