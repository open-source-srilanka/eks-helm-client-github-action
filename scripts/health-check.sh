#!/bin/bash
# Health check script for EKS Helm Client GitHub Action
# This script verifies that the container is healthy and ready to execute

set -e

# Exit codes
readonly HEALTH_OK=0
readonly HEALTH_ERROR=1

# Timeout for health checks (should be less than Docker healthcheck timeout)
readonly HEALTH_TIMEOUT=8

# Color codes for output (only if terminal supports it)
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly NC='\033[0m'
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly NC=''
fi

# Logging functions
log_health_info() {
    echo "[HEALTH] $1" >&2
}

log_health_error() {
    echo -e "${RED}[HEALTH ERROR]${NC} $1" >&2
}

log_health_ok() {
    echo -e "${GREEN}[HEALTH OK]${NC} $1" >&2
}

# Function to check if a command exists and is executable
check_command() {
    local cmd=$1
    local description=${2:-$cmd}
    
    if command -v "$cmd" >/dev/null 2>&1; then
        log_health_info "✓ $description is available"
        return 0
    else
        log_health_error "✗ $description is not available or not executable"
        return 1
    fi
}

# Function to check if a command can execute and return version
check_command_version() {
    local cmd=$1
    local version_flag=${2:---version}
    local description=${3:-$cmd}
    
    if timeout 3 "$cmd" "$version_flag" >/dev/null 2>&1; then
        log_health_info "✓ $description is functional"
        return 0
    else
        log_health_error "✗ $description failed to execute or return version"
        return 1
    fi
}

# Function to check file system health
check_filesystem() {
    log_health_info "Checking filesystem health..."
    
    # Check if required directories exist and are writable
    local dirs=("/opt/kubernetes" "/opt/helm" "/opt/scripts" "/tmp")
    local failed=0
    
    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" && -w "$dir" ]]; then
            log_health_info "✓ Directory $dir is accessible and writable"
        else
            log_health_error "✗ Directory $dir is not accessible or not writable"
            failed=1
        fi
    done
    
    # Test write capability in temp directory
    local test_file="/tmp/health-check-$$"
    if echo "health-check" > "$test_file" 2>/dev/null && rm -f "$test_file" 2>/dev/null; then
        log_health_info "✓ Filesystem write test passed"
    else
        log_health_error "✗ Filesystem write test failed"
        failed=1
    fi
    
    return $failed
}

# Function to check memory and basic system resources
check_system_resources() {
    log_health_info "Checking system resources..."
    
    # Check available memory (should have at least 50MB available)
    if [[ -f /proc/meminfo ]]; then
        local available_mem
        available_mem=$(awk '/MemAvailable/ {print $2}' /proc/meminfo 2>/dev/null || echo "0")
        local available_mb=$((available_mem / 1024))
        
        if [[ $available_mb -gt 50 ]]; then
            log_health_info "✓ Sufficient memory available: ${available_mb}MB"
        else
            log_health_error "✗ Low memory: ${available_mb}MB available"
            return 1
        fi
    fi
    
    # Check disk space in /tmp (should have at least 100MB)
    local available_space
    available_space=$(df /tmp 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
    local available_space_mb=$((available_space / 1024))
    
    if [[ $available_space_mb -gt 100 ]]; then
        log_health_info "✓ Sufficient disk space: ${available_space_mb}MB"
    else
        log_health_error "✗ Low disk space: ${available_space_mb}MB available"
        return 1
    fi
    
    return 0
}

# Function to check required tools
check_required_tools() {
    log_health_info "Checking required tools..."
    
    local failed=0
    
    # Check basic commands
    check_command "bash" "Bash shell" || failed=1
    check_command "curl" "curl" || failed=1
    check_command "jq" "jq JSON processor" || failed=1
    check_command "envsubst" "envsubst" || failed=1
    check_command "nc" "netcat" || failed=1
    
    # Check AWS CLI
    if check_command "aws" "AWS CLI"; then
        check_command_version "aws" "--version" "AWS CLI" || failed=1
    else
        failed=1
    fi
    
    # Check kubectl
    if check_command "kubectl" "kubectl"; then
        check_command_version "kubectl" "version --client --short" "kubectl" || failed=1
    else
        failed=1
    fi
    
    # Check Helm
    if check_command "helm" "Helm"; then
        check_command_version "helm" "version --short" "Helm" || failed=1
    else
        failed=1
    fi
    
    # Check AWS IAM Authenticator
    if check_command "aws-iam-authenticator" "AWS IAM Authenticator"; then
        check_command_version "aws-iam-authenticator" "version" "AWS IAM Authenticator" || failed=1
    else
        failed=1
    fi
    
    # Check eksctl (optional but should be present)
    if check_command "eksctl" "eksctl"; then
        check_command_version "eksctl" "version" "eksctl" || failed=1
    else
        log_health_info "⚠ eksctl not available (optional)"
    fi
    
    return $failed
}

# Function to check configuration templates
check_templates() {
    log_health_info "Checking configuration templates..."
    
    local failed=0
    local templates=("/config.template" "/private-config.template")
    
    for template in "${templates[@]}"; do
        if [[ -f "$template" && -r "$template" ]]; then
            log_health_info "✓ Template $template is accessible"
            
            # Basic validation that template contains expected variables
            if grep -q '\${CLUSTER_NAME}' "$template" && grep -q '\${REGION_CODE}' "$template"; then
                log_health_info "✓ Template $template contains required variables"
            else
                log_health_error "✗ Template $template missing required variables"
                failed=1
            fi
        else
            log_health_error "✗ Template $template is not accessible"
            failed=1
        fi
    done
    
    return $failed
}

# Function to check script permissions and dependencies
check_scripts() {
    log_health_info "Checking script dependencies..."
    
    local failed=0
    local scripts=("/entrypoint.sh" "/cleanup.sh" "/setup-tools.sh")
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" && -x "$script" ]]; then
            log_health_info "✓ Script $script is executable"
        else
            log_health_error "✗ Script $script is not executable or missing"
            failed=1
        fi
    done
    
    return $failed
}

# Function to check environment readiness (basic test)
check_environment_readiness() {
    log_health_info "Checking environment readiness..."
    
    # Test that we can create and manipulate files in working directory
    local test_dir="/opt/scripts/health-test-$$"
    if mkdir -p "$test_dir" 2>/dev/null; then
        if echo "test" > "$test_dir/test.txt" 2>/dev/null; then
            if [[ -f "$test_dir/test.txt" ]]; then
                log_health_info "✓ Environment file operations work"
                rm -rf "$test_dir" 2>/dev/null
                return 0
            fi
        fi
        rm -rf "$test_dir" 2>/dev/null
    fi
    
    log_health_error "✗ Environment file operations failed"
    return 1
}

# Function to validate environment variables (if set)
check_environment_variables() {
    log_health_info "Checking environment configuration..."
    
    # Check if PATH includes required directories
    if echo "$PATH" | grep -q "/usr/local/bin"; then
        log_health_info "✓ PATH includes /usr/local/bin"
    else
        log_health_error "✗ PATH missing /usr/local/bin"
        return 1
    fi
    
    # Check Helm environment variables if they exist
    if [[ -n "${HELM_HOME:-}" ]]; then
        if [[ -d "${HELM_HOME}" ]]; then
            log_health_info "✓ HELM_HOME directory exists: ${HELM_HOME}"
        else
            log_health_error "✗ HELM_HOME directory doesn't exist: ${HELM_HOME}"
            return 1
        fi
    fi
    
    return 0
}

# Main health check function
main_health_check() {
    log_health_info "Starting container health check..."
    
    local overall_status=0
    
    # Run all health checks
    check_filesystem || overall_status=1
    check_system_resources || overall_status=1
    check_required_tools || overall_status=1
    check_templates || overall_status=1
    check_scripts || overall_status=1
    check_environment_readiness || overall_status=1
    check_environment_variables || overall_status=1
    
    # Final health status
    if [[ $overall_status -eq 0 ]]; then
        log_health_ok "Container health check passed"
        return $HEALTH_OK
    else
        log_health_error "Container health check failed"
        return $HEALTH_ERROR
    fi
}

# Quick health check (for frequent docker health checks)
quick_health_check() {
    # Only check the most critical components for quick checks
    local failed=0
    
    # Check if critical commands exist
    command -v kubectl >/dev/null 2>&1 || failed=1
    command -v helm >/dev/null 2>&1 || failed=1
    command -v aws >/dev/null 2>&1 || failed=1
    
    # Check if we can write to temp
    echo "test" > /tmp/quick-health-$$ 2>/dev/null && rm -f /tmp/quick-health-$$ 2>/dev/null || failed=1
    
    return $failed
}

# Handle timeout
timeout_handler() {
    log_health_error "Health check timed out after ${HEALTH_TIMEOUT} seconds"
    exit $HEALTH_ERROR
}

# Set up timeout
trap timeout_handler TERM
timeout $HEALTH_TIMEOUT bash -c '
    # Check if quick mode is requested (for Docker health checks)
    if [[ "${1:-}" == "--quick" ]]; then
        quick_health_check
    else
        main_health_check
    fi
' -- "$@" &

wait $!
exit_code=$?

# Clean exit
trap - TERM
exit $exit_code