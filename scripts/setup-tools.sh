#!/bin/bash
# Setup tools script for EKS Helm Client GitHub Action
# Handles dynamic installation of kubectl, Helm, and other tools based on input parameters

set -e

# Exit codes
readonly SETUP_OK=0
readonly SETUP_ERROR=1

# Default versions (should match action.yml defaults)
readonly DEFAULT_KUBECTL_VERSION="1.28.4"
readonly DEFAULT_HELM_VERSION="3.13.3"
readonly DEFAULT_IAM_AUTHENTICATOR_VERSION="0.6.14"

# Architecture detection
readonly ARCH=$(uname -m)
case $ARCH in
    x86_64)
        readonly PLATFORM="amd64"
        ;;
    aarch64|arm64)
        readonly PLATFORM="arm64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit $SETUP_ERROR
        ;;
esac

readonly OS=$(uname -s | tr '[:upper:]' '[:lower:]')

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
log_setup_info() {
    echo -e "${BLUE}[SETUP]${NC} $1"
}

log_setup_warn() {
    echo -e "${YELLOW}[SETUP WARN]${NC} $1"
}

log_setup_error() {
    echo -e "${RED}[SETUP ERROR]${NC} $1"
}

log_setup_success() {
    echo -e "${GREEN}[SETUP SUCCESS]${NC} $1"
}

# Function to check if we're running as root (needed for installation)
check_permissions() {
    if [[ $EUID -eq 0 ]]; then
        log_setup_info "Running as root - can install tools"
        return 0
    else
        log_setup_error "Not running as root - cannot install tools"
        return 1
    fi
}

# Function to backup existing binary
backup_binary() {
    local binary_path=$1
    local backup_suffix=$(date +%s)
    
    if [[ -f "$binary_path" ]]; then
        local backup_path="${binary_path}.backup.${backup_suffix}"
        log_setup_info "Backing up existing binary: $binary_path -> $backup_path"
        cp "$binary_path" "$backup_path" || {
            log_setup_warn "Failed to backup $binary_path"
            return 1
        }
    fi
    return 0
}

# Function to verify checksum if available
verify_checksum() {
    local file_path=$1
    local expected_checksum=$2
    local algorithm=${3:-sha256}
    
    if [[ -z "$expected_checksum" ]]; then
        log_setup_warn "No checksum provided for verification"
        return 0
    fi
    
    log_setup_info "Verifying $algorithm checksum for $file_path"
    
    local actual_checksum
    case $algorithm in
        sha256)
            actual_checksum=$(sha256sum "$file_path" | cut -d' ' -f1)
            ;;
        sha1)
            actual_checksum=$(sha1sum "$file_path" | cut -d' ' -f1)
            ;;
        *)
            log_setup_error "Unsupported checksum algorithm: $algorithm"
            return 1
            ;;
    esac
    
    if [[ "$actual_checksum" == "$expected_checksum" ]]; then
        log_setup_success "Checksum verification passed"
        return 0
    else
        log_setup_error "Checksum verification failed!"
        log_setup_error "Expected: $expected_checksum"
        log_setup_error "Actual:   $actual_checksum"
        return 1
    fi
}

# Function to download file with retry logic
download_with_retry() {
    local url=$1
    local output_path=$2
    local max_retries=${3:-3}
    local retry_delay=${4:-5}
    
    log_setup_info "Downloading: $url"
    
    for ((i=1; i<=max_retries; i++)); do
        if curl -fsSL --retry 2 --retry-delay 2 --connect-timeout 10 --max-time 300 "$url" -o "$output_path"; then
            log_setup_success "Download completed: $output_path"
            return 0
        else
            log_setup_warn "Download attempt $i failed"
            if [[ $i -lt $max_retries ]]; then
                log_setup_info "Retrying in $retry_delay seconds..."
                sleep $retry_delay
            fi
        fi
    done
    
    log_setup_error "Failed to download after $max_retries attempts: $url"
    return 1
}

# Function to install kubectl
install_kubectl() {
    local version=${1:-$DEFAULT_KUBECTL_VERSION}
    local install_path=${2:-/usr/local/bin/kubectl}
    
    log_setup_info "Installing kubectl version $version for $OS/$PLATFORM"
    
    # Check if version is already installed
    if [[ -f "$install_path" ]]; then
        local current_version
        current_version=$("$install_path" version --client --short 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | sed 's/v//' || echo "unknown")
        
        if [[ "$current_version" == "$version" ]]; then
            log_setup_info "kubectl $version is already installed"
            return 0
        else
            log_setup_info "kubectl $current_version installed, upgrading to $version"
            backup_binary "$install_path"
        fi
    fi
    
    # Download kubectl
    local kubectl_url="https://dl.k8s.io/release/v${version}/bin/${OS}/${PLATFORM}/kubectl"
    local temp_kubectl="/tmp/kubectl-${version}"
    
    if ! download_with_retry "$kubectl_url" "$temp_kubectl"; then
        return 1
    fi
    
    # Download checksum for verification
    local checksum_url="https://dl.k8s.io/v${version}/bin/${OS}/${PLATFORM}/kubectl.sha256"
    local temp_checksum="/tmp/kubectl-${version}.sha256"
    
    if download_with_retry "$checksum_url" "$temp_checksum" 2 3; then
        local expected_checksum
        expected_checksum=$(cat "$temp_checksum" 2>/dev/null)
        verify_checksum "$temp_kubectl" "$expected_checksum" "sha256" || {
            log_setup_error "kubectl checksum verification failed"
            rm -f "$temp_kubectl" "$temp_checksum"
            return 1
        }
    else
        log_setup_warn "Could not download kubectl checksum - installing without verification"
    fi
    
    # Install kubectl
    chmod +x "$temp_kubectl"
    mv "$temp_kubectl" "$install_path" || {
        log_setup_error "Failed to install kubectl to $install_path"
        return 1
    }
    
    # Verify installation
    if "$install_path" version --client --short >/dev/null 2>&1; then
        log_setup_success "kubectl $version installed successfully"
        "$install_path" version --client --short
    else
        log_setup_error "kubectl installation verification failed"
        return 1
    fi
    
    # Cleanup
    rm -f "$temp_checksum"
    return 0
}

# Function to install Helm
install_helm() {
    local version=${1:-$DEFAULT_HELM_VERSION}
    local install_path=${2:-/usr/local/bin/helm}
    
    log_setup_info "Installing Helm version $version for $OS/$PLATFORM"
    
    # Check if version is already installed
    if [[ -f "$install_path" ]]; then
        local current_version
        current_version=$("$install_path" version --short 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | sed 's/v//' || echo "unknown")
        
        if [[ "$current_version" == "$version" ]]; then
            log_setup_info "Helm $version is already installed"
            return 0
        else
            log_setup_info "Helm $current_version installed, upgrading to $version"
            backup_binary "$install_path"
        fi
    fi
    
    # Download Helm
    local helm_url="https://get.helm.sh/helm-v${version}-${OS}-${PLATFORM}.tar.gz"
    local temp_helm_archive="/tmp/helm-${version}.tar.gz"
    
    if ! download_with_retry "$helm_url" "$temp_helm_archive"; then
        return 1
    fi
    
    # Download checksum for verification
    local checksum_url="https://get.helm.sh/helm-v${version}-${OS}-${PLATFORM}.tar.gz.sha256sum"
    local temp_checksum="/tmp/helm-${version}.sha256sum"
    
    if download_with_retry "$checksum_url" "$temp_checksum" 2 3; then
        # Helm checksum file contains filename, extract just the hash
        local expected_checksum
        expected_checksum=$(awk '{print $1}' "$temp_checksum" 2>/dev/null)
        verify_checksum "$temp_helm_archive" "$expected_checksum" "sha256" || {
            log_setup_error "Helm checksum verification failed"
            rm -f "$temp_helm_archive" "$temp_checksum"
            return 1
        }
    else
        log_setup_warn "Could not download Helm checksum - installing without verification"
    fi
    
    # Extract and install Helm
    local temp_dir="/tmp/helm-extract-$$"
    mkdir -p "$temp_dir"
    
    if tar -xzf "$temp_helm_archive" -C "$temp_dir"; then
        local helm_binary="$temp_dir/${OS}-${PLATFORM}/helm"
        if [[ -f "$helm_binary" ]]; then
            chmod +x "$helm_binary"
            mv "$helm_binary" "$install_path" || {
                log_setup_error "Failed to install Helm to $install_path"
                rm -rf "$temp_dir" "$temp_helm_archive" "$temp_checksum"
                return 1
            }
        else
            log_setup_error "Helm binary not found in archive"
            rm -rf "$temp_dir" "$temp_helm_archive" "$temp_checksum"
            return 1
        fi
    else
        log_setup_error "Failed to extract Helm archive"
        rm -rf "$temp_dir" "$temp_helm_archive" "$temp_checksum"
        return 1
    fi
    
    # Verify installation
    if "$install_path" version --short >/dev/null 2>&1; then
        log_setup_success "Helm $version installed successfully"
        "$install_path" version --short
    else
        log_setup_error "Helm installation verification failed"
        rm -rf "$temp_dir" "$temp_helm_archive" "$temp_checksum"
        return 1
    fi
    
    # Cleanup
    rm -rf "$temp_dir" "$temp_helm_archive" "$temp_checksum"
    return 0
}

# Function to install AWS IAM Authenticator
install_aws_iam_authenticator() {
    local version=${1:-$DEFAULT_IAM_AUTHENTICATOR_VERSION}
    local install_path=${2:-/usr/local/bin/aws-iam-authenticator}
    
    log_setup_info "Installing AWS IAM Authenticator version $version for $OS/$PLATFORM"
    
    # Check if version is already installed
    if [[ -f "$install_path" ]]; then
        local current_version
        current_version=$("$install_path" version 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | sed 's/v//' || echo "unknown")
        
        if [[ "$current_version" == "$version" ]]; then
            log_setup_info "AWS IAM Authenticator $version is already installed"
            return 0
        else
            log_setup_info "AWS IAM Authenticator $current_version installed, upgrading to $version"
            backup_binary "$install_path"
        fi
    fi
    
    # Download AWS IAM Authenticator
    local auth_url="https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v${version}/aws-iam-authenticator_${version}_${OS}_${PLATFORM}"
    local temp_auth="/tmp/aws-iam-authenticator-${version}"
    
    if ! download_with_retry "$auth_url" "$temp_auth"; then
        return 1
    fi
    
    # Install AWS IAM Authenticator
    chmod +x "$temp_auth"
    mv "$temp_auth" "$install_path" || {
        log_setup_error "Failed to install AWS IAM Authenticator to $install_path"
        return 1
    }
    
    # Verify installation
    if "$install_path" version >/dev/null 2>&1; then
        log_setup_success "AWS IAM Authenticator $version installed successfully"
        "$install_path" version
    else
        log_setup_error "AWS IAM Authenticator installation verification failed"
        return 1
    fi
    
    return 0
}

# Function to install eksctl
install_eksctl() {
    local install_path=${1:-/usr/local/bin/eksctl}
    
    log_setup_info "Installing latest eksctl for $OS/$PLATFORM"
    
    # Check if eksctl is already installed
    if [[ -f "$install_path" ]] && "$install_path" version >/dev/null 2>&1; then
        local current_version
        current_version=$("$install_path" version 2>/dev/null | head -1 || echo "unknown")
        log_setup_info "eksctl already installed: $current_version"
        log_setup_info "Updating to latest version..."
        backup_binary "$install_path"
    fi
    
    # Download latest eksctl
    local eksctl_url="https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_${OS^}_${PLATFORM}.tar.gz"
    local temp_eksctl_archive="/tmp/eksctl-latest.tar.gz"
    
    if ! download_with_retry "$eksctl_url" "$temp_eksctl_archive"; then
        log_setup_warn "Failed to download eksctl - continuing without it"
        return 0  # Non-critical failure
    fi
    
    # Extract and install eksctl
    local temp_dir="/tmp/eksctl-extract-$$"
    mkdir -p "$temp_dir"
    
    if tar -xzf "$temp_eksctl_archive" -C "$temp_dir"; then
        local eksctl_binary="$temp_dir/eksctl"
        if [[ -f "$eksctl_binary" ]]; then
            chmod +x "$eksctl_binary"
            mv "$eksctl_binary" "$install_path" || {
                log_setup_warn "Failed to install eksctl to $install_path"
                rm -rf "$temp_dir" "$temp_eksctl_archive"
                return 0  # Non-critical failure
            }
        else
            log_setup_warn "eksctl binary not found in archive"
            rm -rf "$temp_dir" "$temp_eksctl_archive"
            return 0  # Non-critical failure
        fi
    else
        log_setup_warn "Failed to extract eksctl archive"
        rm -rf "$temp_dir" "$temp_eksctl_archive"
        return 0  # Non-critical failure
    fi
    
    # Verify installation
    if "$install_path" version >/dev/null 2>&1; then
        log_setup_success "eksctl installed successfully"
        "$install_path" version
    else
        log_setup_warn "eksctl installation verification failed"
    fi
    
    # Cleanup
    rm -rf "$temp_dir" "$temp_eksctl_archive"
    return 0
}

# Function to upgrade AWS CLI if needed
upgrade_aws_cli() {
    log_setup_info "Checking AWS CLI version"
    
    if command -v aws >/dev/null 2>&1; then
        local current_version
        current_version=$(aws --version 2>&1 | cut -d' ' -f1 | cut -d'/' -f2 || echo "unknown")
        log_setup_info "Current AWS CLI version: $current_version"
        
        # For Alpine, we use pip to upgrade
        if command -v pip3 >/dev/null 2>&1; then
            log_setup_info "Upgrading AWS CLI via pip..."
            if pip3 install --upgrade awscli >/dev/null 2>&1; then
                log_setup_success "AWS CLI upgraded successfully"
                aws --version
            else
                log_setup_warn "AWS CLI upgrade failed - continuing with current version"
            fi
        else
            log_setup_info "pip3 not available - keeping current AWS CLI version"
        fi
    else
        log_setup_error "AWS CLI not found"
        return 1
    fi
}

# Function to setup Helm environment
setup_helm_environment() {
    log_setup_info "Setting up Helm environment"
    
    # Create Helm directories if they don't exist
    local helm_dirs=(
        "${HELM_HOME:-/opt/helm}"
        "${HELM_CACHE_HOME:-/opt/helm/cache}"
        "${HELM_CONFIG_HOME:-/opt/helm}"
        "${HELM_DATA_HOME:-/opt/helm}"
    )
    
    for dir in "${helm_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir" || {
                log_setup_error "Failed to create Helm directory: $dir"
                return 1
            }
            log_setup_info "Created Helm directory: $dir"
        fi
    done
    
    # Set proper permissions for Helm directories
    chmod -R 755 "${HELM_HOME:-/opt/helm}" 2>/dev/null || true
    
    log_setup_success "Helm environment setup complete"
    return 0
}

# Function to verify all tools
verify_tools() {
    log_setup_info "Verifying all tools installation"
    
    local tools_status=0
    
    # Check kubectl
    if command -v kubectl >/dev/null 2>&1 && kubectl version --client --short >/dev/null 2>&1; then
        log_setup_success "✓ kubectl is working"
    else
        log_setup_error "✗ kubectl is not working"
        tools_status=1
    fi
    
    # Check Helm
    if command -v helm >/dev/null 2>&1 && helm version --short >/dev/null 2>&1; then
        log_setup_success "✓ Helm is working"
    else
        log_setup_error "✗ Helm is not working"
        tools_status=1
    fi
    
    # Check AWS CLI
    if command -v aws >/dev/null 2>&1 && aws --version >/dev/null 2>&1; then
        log_setup_success "✓ AWS CLI is working"
    else
        log_setup_error "✗ AWS CLI is not working"
        tools_status=1
    fi
    
    # Check AWS IAM Authenticator
    if command -v aws-iam-authenticator >/dev/null 2>&1 && aws-iam-authenticator version >/dev/null 2>&1; then
        log_setup_success "✓ AWS IAM Authenticator is working"
    else
        log_setup_error "✗ AWS IAM Authenticator is not working"
        tools_status=1
    fi
    
    # Check eksctl (optional)
    if command -v eksctl >/dev/null 2>&1 && eksctl version >/dev/null 2>&1; then
        log_setup_success "✓ eksctl is working"
    else
        log_setup_warn "⚠ eksctl is not available (optional)"
    fi
    
    return $tools_status
}

# Function to display tool versions
display_versions() {
    log_setup_info "Tool versions:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if command -v kubectl >/dev/null 2>&1; then
        kubectl version --client --short 2>/dev/null || echo "kubectl: version check failed"
    else
        echo "kubectl: not installed"
    fi
    
    if command -v helm >/dev/null 2>&1; then
        helm version --short 2>/dev/null || echo "Helm: version check failed"
    else
        echo "Helm: not installed"
    fi
    
    if command -v aws >/dev/null 2>&1; then
        aws --version 2>/dev/null || echo "AWS CLI: version check failed"
    else
        echo "AWS CLI: not installed"
    fi
    
    if command -v aws-iam-authenticator >/dev/null 2>&1; then
        echo "AWS IAM Authenticator: $(aws-iam-authenticator version 2>/dev/null || echo 'version check failed')"
    else
        echo "AWS IAM Authenticator: not installed"
    fi
    
    if command -v eksctl >/dev/null 2>&1; then
        echo "eksctl: $(eksctl version 2>/dev/null | head -1 || echo 'version check failed')"
    else
        echo "eksctl: not installed"
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Main setup function
main_setup() {
    log_setup_info "Starting tools setup for EKS Helm Client"
    log_setup_info "Platform: $OS/$PLATFORM"
    
    # Parse command line arguments
    local kubectl_version="${INPUT_KUBECTL_VERSION:-$DEFAULT_KUBECTL_VERSION}"
    local helm_version="${INPUT_HELM_VERSION:-$DEFAULT_HELM_VERSION}"
    local iam_auth_version="${INPUT_IAM_AUTHENTICATOR_VERSION:-$DEFAULT_IAM_AUTHENTICATOR_VERSION}"
    local force_install=false
    local verify_only=false
    local show_versions=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --kubectl-version)
                kubectl_version="$2"
                shift 2
                ;;
            --helm-version)
                helm_version="$2"
                shift 2
                ;;
            --iam-auth-version)
                iam_auth_version="$2"
                shift 2
                ;;
            --force)
                force_install=true
                shift
                ;;
            --verify-only)
                verify_only=true
                shift
                ;;
            --versions)
                show_versions=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --kubectl-version VERSION    Install specific kubectl version"
                echo "  --helm-version VERSION       Install specific Helm version"
                echo "  --iam-auth-version VERSION   Install specific IAM Authenticator version"
                echo "  --force                       Force reinstallation of tools"
                echo "  --verify-only                Only verify tools, don't install"
                echo "  --versions                    Show tool versions and exit"
                echo "  -h, --help                    Show this help message"
                exit 0
                ;;
            *)
                log_setup_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Show versions and exit if requested
    if [[ "$show_versions" == "true" ]]; then
        display_versions
        exit 0
    fi
    
    # Verify only mode
    if [[ "$verify_only" == "true" ]]; then
        verify_tools
        exit $?
    fi
    
    # Check permissions for installation
    if ! check_permissions; then
        log_setup_error "Insufficient permissions for tool installation"
        exit $SETUP_ERROR
    fi
    
    local setup_failed=false
    
    # Install tools
    if [[ "$force_install" == "true" ]] || ! command -v kubectl >/dev/null 2>&1; then
        install_kubectl "$kubectl_version" || setup_failed=true
    fi
    
    if [[ "$force_install" == "true" ]] || ! command -v helm >/dev/null 2>&1; then
        install_helm "$helm_version" || setup_failed=true
    fi
    
    if [[ "$force_install" == "true" ]] || ! command -v aws-iam-authenticator >/dev/null 2>&1; then
        install_aws_iam_authenticator "$iam_auth_version" || setup_failed=true
    fi
    
    # Install/upgrade optional tools
    install_eksctl || true  # Non-critical
    upgrade_aws_cli || true  # Non-critical
    
    # Setup environments
    setup_helm_environment || setup_failed=true
    
    # Final verification
    if ! verify_tools; then
        setup_failed=true
    fi
    
    # Display final status
    if [[ "$setup_failed" == "true" ]]; then
        log_setup_error "Tools setup completed with errors"
        exit $SETUP_ERROR
    else
        log_setup_success "All tools setup completed successfully"
        display_versions
        exit $SETUP_OK
    fi
}

# Handle script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_setup "$@"
fi