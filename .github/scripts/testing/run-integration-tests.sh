#!/bin/bash
# .github/scripts/testing/run-integration-tests.sh

set -e

# Source shared testing utilities
source "$(dirname "$0")/utils.sh"

# Reset counters for this script
reset_counters

# Test configuration
readonly TEST_CLUSTER_NAME="${TEST_CLUSTER_NAME:-test-eks-cluster}"
readonly TEST_REGION="${TEST_REGION:-us-west-2}"
readonly DOCKER_IMAGE_TAG="${DOCKER_IMAGE_TAG:-eks-helm-client:test}"

check_prerequisites() {
    log_info "Checking prerequisites"
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is required for integration tests"
        exit 1
    fi
    
    # Check if we're in GitHub Actions
    if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        log_info "Running in GitHub Actions environment"
    else
        log_info "Running in local environment"
    fi
    
    log_success "Prerequisites check passed"
}

# Helper function to run tests
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    log_info "Running test: $test_name"
    
    if $test_function; then
        log_test_result "PASS" "$test_name"
        return 0
    else
        log_test_result "FAIL" "$test_name"
        return 1
    fi
}

test_docker_build() {
    log_info "Building Docker image: $DOCKER_IMAGE_TAG"
    
    # Capture both stdout and stderr
    local build_output
    if build_output=$(docker build -t "$DOCKER_IMAGE_TAG" . 2>&1); then
        log_info "Docker build completed successfully"
        
        # Check image exists
        if docker images "$DOCKER_IMAGE_TAG" --format "table {{.Repository}}:{{.Tag}}" | grep -q "$DOCKER_IMAGE_TAG"; then
            log_info "✓ Docker image created: $DOCKER_IMAGE_TAG"
            return 0
        else
            log_error "Image not found after build"
            return 1
        fi
    else
        log_error "Docker build failed"
        echo "Build output:" >&2
        echo "$build_output" >&2
        return 1
    fi
}

test_container_startup() {
    log_info "Testing container startup..."
    
    # Test basic container startup without executing entrypoint
    local output
    if output=$(docker run --rm \
        --entrypoint="/bin/sh" \
        "$DOCKER_IMAGE_TAG" \
        -c "echo 'Container started successfully'" 2>&1); then
        
        if echo "$output" | grep -q "Container started successfully"; then
            log_info "✓ Container starts successfully"
            return 0
        else
            log_error "Unexpected container output: $output"
            return 1
        fi
    else
        log_error "Container failed to start"
        echo "Container output:" >&2
        echo "$output" >&2
        return 1
    fi
}

test_tools_availability() {
    local tools=("kubectl" "helm" "aws" "jq" "curl")
    local all_available=true
    
    log_info "Checking tool availability in container..."
    
    for tool in "${tools[@]}"; do
        if docker run --rm --entrypoint="/bin/sh" "$DOCKER_IMAGE_TAG" -c "command -v $tool" >/dev/null 2>&1; then
            log_info "  ✓ $tool available"
        else
            log_info "  ✗ $tool not available"
            all_available=false
        fi
    done
    
    return $([[ "$all_available" == "true" ]] && echo 0 || echo 1)
}

test_tool_versions() {
    log_info "Checking tool versions..."
    
    # Test kubectl version (client only, no server connection needed)
    local kubectl_version
    if kubectl_version=$(docker run --rm --entrypoint="/bin/sh" "$DOCKER_IMAGE_TAG" -c "kubectl version --client --short 2>/dev/null || kubectl version --client=true --short 2>/dev/null || kubectl version --client 2>/dev/null | head -1"); then
        if [[ "$kubectl_version" != "error" && -n "$kubectl_version" ]]; then
            log_info "  ✓ kubectl: $kubectl_version"
        else
            log_error "kubectl version check failed - no output"
            return 1
        fi
    else
        log_error "kubectl version command failed"
        return 1
    fi
    
    # Test helm version (client only)
    local helm_version
    if helm_version=$(docker run --rm --entrypoint="/bin/sh" "$DOCKER_IMAGE_TAG" -c "helm version --short --client 2>/dev/null || helm version --short 2>/dev/null || helm version 2>/dev/null | head -1"); then
        if [[ "$helm_version" != "error" && -n "$helm_version" ]]; then
            log_info "  ✓ Helm: $helm_version"
        else
            log_error "Helm version check failed - no output"
            return 1
        fi
    else
        log_error "Helm version command failed"
        return 1
    fi
    
    # Test AWS CLI version
    local aws_version
    if aws_version=$(docker run --rm --entrypoint="/bin/sh" "$DOCKER_IMAGE_TAG" -c "aws --version 2>&1 | head -1"); then
        if [[ "$aws_version" != "error" && -n "$aws_version" ]]; then
            log_info "  ✓ AWS CLI: $aws_version"
        else
            log_error "AWS CLI version check failed - no output"
            return 1
        fi
    else
        log_error "AWS CLI version command failed"
        return 1
    fi
    
    return 0
}

test_dry_run_mode() {
    log_info "Testing dry run mode..."
    
    local output
    # Pass dummy AWS credentials to avoid validation failure in dry run
    if output=$(docker run --rm \
        -e INPUT_CLUSTER_NAME="$TEST_CLUSTER_NAME" \
        -e INPUT_REGION="$TEST_REGION" \
        -e INPUT_DRY_RUN="true" \
        -e INPUT_ARGS="echo 'test command'" \
        -e AWS_ACCESS_KEY_ID="dummy-key-for-dry-run" \
        -e AWS_SECRET_ACCESS_KEY="dummy-secret-for-dry-run" \
        -e AWS_DEFAULT_REGION="$TEST_REGION" \
        "$DOCKER_IMAGE_TAG" \
        "echo 'test command'" 2>&1); then
        
        if echo "$output" | grep -q "DRY RUN MODE"; then
            log_info "✓ Dry run mode detected correctly"
            return 0
        elif echo "$output" | grep -q "Commands to execute:"; then
            log_info "✓ Dry run mode working (shows commands without executing)"
            return 0
        else
            log_error "Dry run mode not working as expected"
            echo "Output:" >&2
            echo "$output" >&2
            return 1
        fi
    else
        log_error "Dry run execution failed"
        echo "Output:" >&2
        echo "$output" >&2
        return 1
    fi
}

test_error_handling() {
    log_info "Testing error handling for missing parameters..."
    
    # Test missing cluster name - this should fail
    local output
    if output=$(docker run --rm \
        -e INPUT_REGION="$TEST_REGION" \
        -e INPUT_ARGS="echo 'test'" \
        "$DOCKER_IMAGE_TAG" \
        "echo 'test'" 2>&1); then
        
        # If the command succeeded, that's unexpected
        log_error "Should have failed with missing cluster name"
        return 1
    else
        # Command failed as expected, check the error message
        if echo "$output" | grep -q "CLUSTER_NAME is required"; then
            log_info "✓ Proper error handling for missing cluster name"
            return 0
        else
            log_error "Did not produce expected error for missing cluster-name"
            echo "Output:" >&2
            echo "$output" >&2
            return 1
        fi
    fi
}

test_health_check() {
    log_info "Testing health check script..."
    
    # Test health check script directly
    local output
    if output=$(docker run --rm \
        --entrypoint="/health-check.sh" \
        "$DOCKER_IMAGE_TAG" 2>&1); then
        log_info "✓ Health check script executed successfully"
        return 0
    else
        log_error "Health check script failed"
        echo "Health check output:" >&2
        echo "$output" >&2
        return 1
    fi
}

test_template_validation() {
    log_info "Testing configuration templates..."
    
    # Test that templates exist and have required variables
    local output
    if output=$(docker run --rm \
        --entrypoint="/bin/sh" \
        "$DOCKER_IMAGE_TAG" \
        -c "ls -la /config.template /private-config.template 2>/dev/null || echo 'templates missing'" 2>&1); then
        
        if echo "$output" | grep -q "templates missing"; then
            log_error "Configuration templates missing"
            return 1
        else
            log_info "✓ Configuration templates present"
            return 0
        fi
    else
        log_error "Template validation failed"
        return 1
    fi
}

test_script_permissions() {
    log_info "Testing script permissions in container..."
    
    local scripts=("/entrypoint.sh" "/health-check.sh" "/setup-tools.sh" "/cleanup.sh")
    local all_executable=true
    
    for script in "${scripts[@]}"; do
        if docker run --rm --entrypoint="/bin/sh" "$DOCKER_IMAGE_TAG" -c "test -x $script" 2>/dev/null; then
            log_info "  ✓ $script is executable"
        else
            log_info "  ✗ $script is not executable"
            all_executable=false
        fi
    done
    
    return $([[ "$all_executable" == "true" ]] && echo 0 || echo 1)
}

test_environment_variables() {
    log_info "Testing environment variable handling..."
    
    local output
    if output=$(docker run --rm \
        --entrypoint="/bin/sh" \
        "$DOCKER_IMAGE_TAG" \
        -c "echo KUBECONFIG=\$KUBECONFIG; echo HELM_HOME=\$HELM_HOME" 2>&1); then
        
        if echo "$output" | grep -q "KUBECONFIG=" && echo "$output" | grep -q "HELM_HOME="; then
            log_info "✓ Environment variables are set correctly"
            return 0
        else
            log_error "Environment variables not set correctly"
            echo "Output:" >&2
            echo "$output" >&2
            return 1
        fi
    else
        log_error "Environment variable test failed"
        return 1
    fi
}

cleanup_test_images() {
    log_info "Cleaning up test images..."
    
    # Remove test image if it exists
    if docker images "$DOCKER_IMAGE_TAG" --format "table {{.Repository}}:{{.Tag}}" | grep -q "$DOCKER_IMAGE_TAG"; then
        if docker rmi "$DOCKER_IMAGE_TAG" >/dev/null 2>&1; then
            log_info "Test image removed: $DOCKER_IMAGE_TAG"
        else
            log_warn "Failed to remove test image: $DOCKER_IMAGE_TAG"
            increment_warnings
        fi
    fi
}

main() {
    log_info "=== EKS Helm Client Integration Tests ==="
    
    # Set up cleanup on exit
    trap cleanup_test_images EXIT
    
    # Check prerequisites
    check_prerequisites
    
    # Run tests in order
    run_test "Docker Image Build" test_docker_build || exit 1
    run_test "Container Startup" test_container_startup
    run_test "Tools Availability" test_tools_availability
    run_test "Tool Versions" test_tool_versions
    run_test "Dry Run Mode" test_dry_run_mode
    run_test "Error Handling" test_error_handling
    run_test "Health Check" test_health_check
    run_test "Template Validation" test_template_validation
    run_test "Script Permissions" test_script_permissions
    run_test "Environment Variables" test_environment_variables
    
    # Exit with summary
    exit_with_summary "Integration Tests"
}

main