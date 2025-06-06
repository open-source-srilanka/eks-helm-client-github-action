#!/bin/bash
# Cleanup script for EKS Helm Client GitHub Action
# Handles secure cleanup of sensitive data, temporary files, and container state

set +e  # Don't exit on cleanup errors - we want to clean up as much as possible

# Exit codes
readonly CLEANUP_OK=0
readonly CLEANUP_ERROR=1

# Cleanup modes
readonly CLEANUP_MODE_NORMAL="normal"
readonly CLEANUP_MODE_EMERGENCY="emergency"
readonly CLEANUP_MODE_DEEP="deep"

# Color codes for output
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m'
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly NC=''
fi

# Logging functions
log_cleanup_info() {
    echo -e "${BLUE}[CLEANUP]${NC} $1" >&2
}

log_cleanup_warn() {
    echo -e "${YELLOW}[CLEANUP WARN]${NC} $1" >&2
}

log_cleanup_error() {
    echo -e "${RED}[CLEANUP ERROR]${NC} $1" >&2
}

log_cleanup_success() {
    echo -e "${GREEN}[CLEANUP SUCCESS]${NC} $1" >&2
}

# Function to securely remove file or directory
secure_remove() {
    local target="$1"
    local description="${2:-$target}"
    
    if [[ ! -e "$target" ]]; then
        log_cleanup_info "✓ $description (not found)"
        return 0
    fi
    
    # Check if it's a file or directory and handle appropriately
    if [[ -f "$target" ]]; then
        # For files, overwrite with random data first for sensitive files
        if [[ "$target" =~ (kubeconfig|credentials|token|secret|password|key|config) ]]; then
            log_cleanup_info "Securely wiping $description"
            if command -v shred >/dev/null 2>&1; then
                shred -vfz -n 3 "$target" 2>/dev/null || {
                    log_cleanup_warn "Shred failed for $target, using basic overwrite"
                    dd if=/dev/urandom of="$target" bs=1024 count=1 2>/dev/null || true
                }
            else
                # Fallback: overwrite with random data
                dd if=/dev/urandom of="$target" bs=1024 count=1 2>/dev/null || true
            fi
        fi
        
        rm -f "$target" 2>/dev/null && log_cleanup_info "✓ Removed $description" || log_cleanup_warn "✗ Failed to remove $description"
    elif [[ -d "$target" ]]; then
        rm -rf "$target" 2>/dev/null && log_cleanup_info "✓ Removed directory $description" || log_cleanup_warn "✗ Failed to remove directory $description"
    else
        rm -rf "$target" 2>/dev/null && log_cleanup_info "✓ Removed $description" || log_cleanup_warn "✗ Failed to remove $description"
    fi
}

# Function to clean up kubeconfig files
cleanup_kubeconfig() {
    log_cleanup_info "Cleaning up kubeconfig files"
    
    local kubeconfig_locations=(
        "$KUBECONFIG"
        "${INPUT_KUBECONFIG_PATH:-}"
        "/opt/kubernetes/config"
        "/root/.kube/config"
        "/home/runner/.kube/config"
        "$HOME/.kube/config"
        "/tmp/kubeconfig"
        "/tmp/kubeconfig.*"
    )
    
    # Clean up specific kubeconfig files
    for config in "${kubeconfig_locations[@]}"; do
        if [[ -n "$config" ]]; then
            secure_remove "$config" "kubeconfig file"
        fi
    done
    
    # Clean up any kubeconfig files in temp directories
    find /tmp -name "*kubeconfig*" -type f 2>/dev/null | while read -r file; do
        secure_remove "$file" "temporary kubeconfig"
    done
    
    # Clean up .kube directories
    for kube_dir in "/root/.kube" "/home/runner/.kube" "$HOME/.kube"; do
        if [[ -d "$kube_dir" ]]; then
            secure_remove "$kube_dir" "kube directory"
        fi
    done
}

# Function to clean up AWS credentials and tokens
cleanup_aws_credentials() {
    log_cleanup_info "Cleaning up AWS credentials and tokens"
    
    # Clear AWS environment variables
    local aws_env_vars=(
        "AWS_ACCESS_KEY_ID"
        "AWS_SECRET_ACCESS_KEY"
        "AWS_SESSION_TOKEN"
        "AWS_SECURITY_TOKEN"
        "AWS_CREDENTIAL_FILE"
        "AWS_SHARED_CREDENTIALS_FILE"
        "AWS_WEB_IDENTITY_TOKEN_FILE"
        "AWS_ROLE_ARN"
        "AWS_ROLE_SESSION_NAME"
    )
    
    for var in "${aws_env_vars[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            unset "$var" 2>/dev/null || true
            log_cleanup_info "✓ Cleared environment variable $var"
        fi
    done
    
    # Clean up AWS credential files
    local aws_credential_locations=(
        "/root/.aws"
        "/home/runner/.aws"
        "$HOME/.aws"
        "/tmp/.aws"
        "/tmp/aws-credentials"
        "/tmp/aws-token"
    )
    
    for location in "${aws_credential_locations[@]}"; do
        if [[ -e "$location" ]]; then
            secure_remove "$location" "AWS credentials"
        fi
    done
    
    # Clean up any AWS temporary files
    find /tmp -name "*aws*" -name "*credential*" -type f 2>/dev/null | while read -r file; do
        secure_remove "$file" "AWS temporary file"
    done
    
    find /tmp -name "*aws*" -name "*token*" -type f 2>/dev/null | while read -r file; do
        secure_remove "$file" "AWS token file"
    done
}

# Function to clean up Helm data
cleanup_helm_data() {
    log_cleanup_info "Cleaning up Helm data and repositories"
    
    # Clear Helm-related environment variables
    local helm_env_vars=(
        "HELM_REGISTRY_PASSWORD"
        "HELM_REGISTRY_USERNAME"
        "HELM_REPO_PASSWORD"
        "HELM_REPO_USERNAME"
    )
    
    for var in "${helm_env_vars[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            unset "$var" 2>/dev/null || true
            log_cleanup_info "✓ Cleared Helm environment variable $var"
        fi
    done
    
    # Clean up Helm directories and files
    local helm_locations=(
        "${HELM_HOME:-/opt/helm}"
        "${HELM_CACHE_HOME:-/opt/helm/cache}"
        "${HELM_CONFIG_HOME:-/opt/helm}"
        "${HELM_DATA_HOME:-/opt/helm}"
        "/root/.helm"
        "/home/runner/.helm"
        "$HOME/.helm"
        "/root/.config/helm"
        "/home/runner/.config/helm"
        "$HOME/.config/helm"
    )
    
    for location in "${helm_locations[@]}"; do
        if [[ -d "$location" ]]; then
            # Specifically target sensitive files first
            find "$location" -name "repositories.yaml" -type f 2>/dev/null | while read -r file; do
                secure_remove "$file" "Helm repositories file"
            done
            
            find "$location" -name "*password*" -type f 2>/dev/null | while read -r file; do
                secure_remove "$file" "Helm password file"
            done
            
            find "$location" -name "*credential*" -type f 2>/dev/null | while read -r file; do
                secure_remove "$file" "Helm credential file"
            done
            
            # Remove cache and temporary files
            if [[ "$location" =~ cache ]]; then
                secure_remove "$location" "Helm cache directory"
            fi
        fi
    done
    
    # Clean up Helm temporary files
    find /tmp -name "*helm*" -type f 2>/dev/null | while read -r file; do
        secure_remove "$file" "Helm temporary file"
    done
}

# Function to clean up container registry credentials
cleanup_registry_credentials() {
    log_cleanup_info "Cleaning up container registry credentials"
    
    # Clear registry-related environment variables
    local registry_env_vars=(
        "INPUT_HELM_REGISTRY_PASSWORD"
        "INPUT_HELM_REGISTRY_USERNAME"
        "DOCKER_PASSWORD"
        "DOCKER_USERNAME"
        "REGISTRY_PASSWORD"
        "REGISTRY_USERNAME"
        "HARBOR_PASSWORD"
        "HARBOR_USERNAME"
        "NEXUS_PASSWORD"
        "NEXUS_USERNAME"
    )
    
    for var in "${registry_env_vars[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            unset "$var" 2>/dev/null || true
            log_cleanup_info "✓ Cleared registry environment variable $var"
        fi
    done
    
    # Clean up Docker/registry config files
    local registry_config_locations=(
        "/root/.docker"
        "/home/runner/.docker"
        "$HOME/.docker"
        "/tmp/.docker"
        "/tmp/docker-config"
        "/tmp/registry-config"
    )
    
    for location in "${registry_config_locations[@]}"; do
        if [[ -e "$location" ]]; then
            secure_remove "$location" "registry configuration"
        fi
    done
}

# Function to clean up temporary files and directories
cleanup_temporary_files() {
    log_cleanup_info "Cleaning up temporary files and directories"
    
    # Clean up our specific temporary files
    local temp_patterns=(
        "/tmp/kubectl-*"
        "/tmp/helm-*"
        "/tmp/aws-*"
        "/tmp/eks-*"
        "/tmp/health-*"
        "/tmp/setup-*"
        "/tmp/cluster-*"
        "/tmp/*.tmp"
        "/tmp/*.temp"
        "/tmp/.*-$$"
    )
    
    for pattern in "${temp_patterns[@]}"; do
        # Use find to handle glob patterns safely
        find /tmp -name "$(basename "$pattern")" -maxdepth 1 2>/dev/null | while read -r file; do
            secure_remove "$file" "temporary file"
        done
    done
    
    # Clean up any files with our process ID
    if [[ -n "$BASHPID" ]]; then
        find /tmp -name "*-$BASHPID" -o -name "*-$$" 2>/dev/null | while read -r file; do
            secure_remove "$file" "process-specific temporary file"
        done
    fi
    
    # Clean up container-specific directories if they exist
    local container_temp_dirs=(
        "/opt/scripts/temp"
        "/opt/kubernetes/temp"
        "/opt/helm/temp"
    )
    
    for dir in "${container_temp_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            secure_remove "$dir" "container temporary directory"
        fi
    done
}

# Function to clean up process-related data
cleanup_processes() {
    log_cleanup_info "Cleaning up process-related data"
    
    # Look for any background processes we might have started
    local process_patterns=(
        "kubectl"
        "helm"
        "aws"
        "aws-iam-authenticator"
    )
    
    # Only kill processes we own and that might be stuck
    for pattern in "${process_patterns[@]}"; do
        pgrep -f "$pattern" 2>/dev/null | while read -r pid; do
            # Check if we own this process
            if ps -o user= -p "$pid" 2>/dev/null | grep -q "$(whoami)"; then
                # Check if it's been running for more than 5 minutes (might be stuck)
                local elapsed
                elapsed=$(ps -o etime= -p "$pid" 2>/dev/null | tr -d ' ')
                if [[ "$elapsed" =~ ^[0-9][0-9]:|^[1-9][0-9][0-9]: ]]; then
                    log_cleanup_warn "Terminating long-running process: $pattern (PID: $pid)"
                    kill -TERM "$pid" 2>/dev/null || true
                    sleep 2
                    kill -KILL "$pid" 2>/dev/null || true
                fi
            fi
        done
    done
}

# Function to clean up log files and output
cleanup_logs() {
    log_cleanup_info "Cleaning up log files"
    
    # Clean up any log files we might have created
    local log_locations=(
        "/tmp/*.log"
        "/opt/scripts/*.log"
        "/opt/kubernetes/*.log"
        "/opt/helm/*.log"
        "/var/log/eks-helm-client.log"
    )
    
    for pattern in "${log_locations[@]}"; do
        find "$(dirname "$pattern")" -name "$(basename "$pattern")" -type f 2>/dev/null | while read -r file; do
            secure_remove "$file" "log file"
        done
    done
}

# Function to clean up environment variables
cleanup_environment() {
    log_cleanup_info "Cleaning up environment variables"
    
    # List of sensitive environment variables to clear
    local sensitive_vars=(
        # AWS variables
        "AWS_ACCESS_KEY_ID"
        "AWS_SECRET_ACCESS_KEY"
        "AWS_SESSION_TOKEN"
        "AWS_SECURITY_TOKEN"
        
        # Helm/Registry variables
        "HELM_REGISTRY_PASSWORD"
        "HELM_REGISTRY_USERNAME"
        "INPUT_HELM_REGISTRY_PASSWORD"
        "INPUT_HELM_REGISTRY_USERNAME"
        
        # Docker/Registry variables
        "DOCKER_PASSWORD"
        "DOCKER_USERNAME"
        "REGISTRY_PASSWORD"
        "REGISTRY_USERNAME"
        
        # Custom sensitive variables
        "KUBECONFIG"
        "CLUSTER_ENDPOINT"
        "CLUSTER_CA"
        "PRIVATE_KEY"
        "SECRET_KEY"
        "TOKEN"
        "PASSWORD"
        "API_KEY"
    )
    
    for var in "${sensitive_vars[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            unset "$var" 2>/dev/null || true
            log_cleanup_info "✓ Cleared environment variable $var"
        fi
    done
    
    # Clear any variables that contain "secret", "password", "token", or "key"
    env | grep -i -E "(secret|password|token|key)" | cut -d'=' -f1 | while read -r var; do
        if [[ "$var" != "PATH" && "$var" != "HOME" && "$var" != "USER" ]]; then
            unset "$var" 2>/dev/null || true
            log_cleanup_info "✓ Cleared sensitive environment variable $var"
        fi
    done
}

# Function to verify cleanup
verify_cleanup() {
    log_cleanup_info "Verifying cleanup completion"
    
    local verification_failed=false
    
    # Check for sensitive files that should be gone
    local sensitive_patterns=(
        "/tmp/*kubeconfig*"
        "/tmp/*credential*"
        "/tmp/*password*"
        "/tmp/*secret*"
        "/tmp/*token*"
        "/root/.aws"
        "/root/.kube"
        "/root/.helm"
        "/root/.docker"
    )
    
    for pattern in "${sensitive_patterns[@]}"; do
        if ls $pattern 2>/dev/null | head -1 >/dev/null; then
            log_cleanup_warn "Sensitive files still exist: $pattern"
            verification_failed=true
        fi
    done
    
    # Check for sensitive environment variables
    local sensitive_env_check=(
        "AWS_SECRET_ACCESS_KEY"
        "AWS_SESSION_TOKEN"
        "HELM_REGISTRY_PASSWORD"
        "DOCKER_PASSWORD"
    )
    
    for var in "${sensitive_env_check[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            log_cleanup_warn "Sensitive environment variable still set: $var"
            verification_failed=true
        fi
    done
    
    if [[ "$verification_failed" == "true" ]]; then
        log_cleanup_warn "Cleanup verification found remaining sensitive data"
        return 1
    else
        log_cleanup_success "Cleanup verification passed"
        return 0
    fi
}

# Function for emergency cleanup (minimal logging, maximum speed)
emergency_cleanup() {
    # Emergency mode - clean up as fast as possible with minimal logging
    echo "[EMERGENCY CLEANUP] Starting emergency cleanup" >&2
    
    # Critical sensitive files
    rm -rf /tmp/*kubeconfig* /tmp/*credential* /tmp/*secret* /tmp/*password* /tmp/*token* 2>/dev/null || true
    rm -rf /root/.aws /root/.kube /root/.helm /root/.docker 2>/dev/null || true
    rm -rf /home/runner/.aws /home/runner/.kube /home/runner/.helm /home/runner/.docker 2>/dev/null || true
    
    # Critical environment variables
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN 2>/dev/null || true
    unset HELM_REGISTRY_PASSWORD DOCKER_PASSWORD KUBECONFIG 2>/dev/null || true
    
    echo "[EMERGENCY CLEANUP] Emergency cleanup completed" >&2
}

# Function for deep cleanup (thorough cleanup for debugging)
deep_cleanup() {
    log_cleanup_info "Starting deep cleanup mode"
    
    # Normal cleanup first
    cleanup_kubeconfig
    cleanup_aws_credentials
    cleanup_helm_data
    cleanup_registry_credentials
    cleanup_temporary_files
    cleanup_processes
    cleanup_logs
    cleanup_environment
    
    # Additional deep cleaning
    log_cleanup_info "Performing additional deep cleanup"
    
    # Clean up any hidden files in temp
    find /tmp -name ".*" -type f 2>/dev/null | while read -r file; do
        if [[ "$file" =~ (secret|password|token|credential|key|config) ]]; then
            secure_remove "$file" "hidden sensitive file"
        fi
    done
    
    # Clean up any SUID/SGID files we might have created (security)
    find /tmp -perm /6000 -type f 2>/dev/null | while read -r file; do
        secure_remove "$file" "SUID/SGID file"
    done
    
    # Clean up any named pipes or sockets
    find /tmp -type p -o -type s 2>/dev/null | while read -r file; do
        secure_remove "$file" "named pipe/socket"
    done
    
    # Additional process cleanup
    pkill -f "kubectl\|helm\|aws" 2>/dev/null || true
    
    log_cleanup_success "Deep cleanup completed"
}

# Signal handler for graceful cleanup
signal_handler() {
    local signal=$1
    log_cleanup_warn "Received signal $signal - performing emergency cleanup"
    emergency_cleanup
    exit $CLEANUP_ERROR
}

# Main cleanup function
main_cleanup() {
    local cleanup_mode="${1:-$CLEANUP_MODE_NORMAL}"
    local verify="${2:-true}"
    
    log_cleanup_info "Starting cleanup (mode: $cleanup_mode)"
    
    # Set up signal handlers
    trap 'signal_handler TERM' TERM
    trap 'signal_handler INT' INT
    trap 'signal_handler HUP' HUP
    
    case "$cleanup_mode" in
        "$CLEANUP_MODE_EMERGENCY")
            emergency_cleanup
            ;;
        "$CLEANUP_MODE_DEEP")
            deep_cleanup
            ;;
        "$CLEANUP_MODE_NORMAL"|*)
            cleanup_kubeconfig
            cleanup_aws_credentials
            cleanup_helm_data
            cleanup_registry_credentials
            cleanup_temporary_files
            cleanup_processes
            cleanup_logs
            cleanup_environment
            ;;
    esac
    
    # Verification step
    if [[ "$verify" == "true" && "$cleanup_mode" != "$CLEANUP_MODE_EMERGENCY" ]]; then
        if verify_cleanup; then
            log_cleanup_success "Cleanup completed successfully"
            return $CLEANUP_OK
        else
            log_cleanup_warn "Cleanup completed with warnings"
            return $CLEANUP_ERROR
        fi
    else
        log_cleanup_success "Cleanup completed"
        return $CLEANUP_OK
    fi
}

# Handle script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Parse command line arguments
    cleanup_mode="$CLEANUP_MODE_NORMAL"
    verify="true"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --emergency)
                cleanup_mode="$CLEANUP_MODE_EMERGENCY"
                verify="false"
                shift
                ;;
            --deep)
                cleanup_mode="$CLEANUP_MODE_DEEP"
                shift
                ;;
            --no-verify)
                verify="false"
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --emergency    Emergency cleanup (fast, minimal logging)"
                echo "  --deep         Deep cleanup (thorough, for debugging)"
                echo "  --no-verify    Skip cleanup verification"
                echo "  -h, --help     Show this help message"
                echo ""
                echo "Cleanup modes:"
                echo "  normal    - Standard cleanup of sensitive data and temp files"
                echo "  emergency - Fast cleanup with minimal logging"
                echo "  deep      - Thorough cleanup including hidden files and processes"
                exit 0
                ;;
            *)
                log_cleanup_error "Unknown option: $1"
                exit $CLEANUP_ERROR
                ;;
        esac
    done
    
    main_cleanup "$cleanup_mode" "$verify"
    exit $?
fi