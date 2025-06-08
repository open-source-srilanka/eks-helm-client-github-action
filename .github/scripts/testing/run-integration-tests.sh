#!/bin/bash
# .github/scripts/testing/run-integration-tests.sh

set -e

# Source shared testing utilities
source "$(dirname "$0")/utils.sh"

# Test configuration
readonly TEST_CLUSTER_NAME="${TEST_CLUSTER_NAME:-test-eks-cluster}"
readonly TEST_REGION="${TEST_REGION:-us-west-2}"
readonly DOCKER_IMAGE_TAG="${DOCKER_IMAGE_TAG:-eks-helm-client:test}"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

check_prerequisites() {
    log_message "INFO" "Checking prerequisites"
    if ! command -v docker >/dev/null 2>&1; then
        log_message "FAIL" "Prerequisites" "Docker is required for integration tests"
        exit 1
    fi
    
    # Check if we're in GitHub Actions
    if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        log_message "INFO" "Running in GitHub Actions environment"
    else
        log_message "INFO" "Running in local environment"
    fi
}

test_docker_build() {
    local test_name="Docker Image Build"
    log_message "INFO" "Building Docker image..."
    
    # Capture both stdout and stderr
    local build_output
    if build_output=$(docker build -t "$DOCKER_IMAGE_TAG" . 2>&1); then
        log_message "PASS" "$test_name"
        
        # Check image exists
        if docker images "$DOCKER_IMAGE_TAG" --format "table {{.Repository}}:{{.Tag}}" | grep -q "$DOCKER_IMAGE_TAG"; then
            log_message "INFO" "Docker image created successfully: $DOCKER_IMAGE_TAG"
        else
            log_message "FAIL" "$test_name" "Image not found after build"
            return 1
        fi
    else
        log_message "FAIL" "$test_name" "Docker build failed"
        echo "Build output:"
        echo "$build_output"
        return 1
    fi
}

test_container_startup() {
    local test_name="Container Startup"
    
    log_message "INFO" "Testing container startup..."
    
    # Test basic container startup without executing entrypoint
    local output
    if output=$(docker run --rm \
        --entrypoint="/bin/sh" \
        "$DOCKER_IMAGE_TAG" \
        -c "echo 'Container started successfully'" 2>&1); then
        
        if echo "$output" | grep -q "Container started successfully"; then
            log_message "PASS" "$test_name"
        else
            log_message "FAIL" "$test_name" "Unexpected output: $output"
            return 1
        fi
    else
        log_message "FAIL" "$test_name" "Container failed to start"
        echo "Container output:"
        echo "$output"
        return 1
    fi
}

test_tools_availability() {
    local test_name="Tools Availability"
    local tools=("kubectl" "helm" "aws" "jq" "curl")
    local all_available=true
    
    log_message "INFO" "Checking tool availability in container..."
    
    for tool in "${tools[@]}"; do
        if docker run --rm --entrypoint="/bin/sh" "$DOCKER_IMAGE_TAG" -c "command -v $tool" >/dev/null 2>&1; then
            log_message "INFO" "  ✓ $tool available"
        else
            log_message "FAIL" "  ✗ $tool not available"
            all_available=false
        fi
    done
    
    if [[ "$all_available" == "true" ]]; then
        log_message "PASS" "$test_name"
    else
        log_message "FAIL" "$test_name" "Some required tools are missing"
        return 1
    fi
}

test_tool_versions() {
    local test_name="Tool Versions"
    
    log_message "INFO" "Checking tool versions..."
    
    # Test kubectl version
    local kubectl_version
    if kubectl_version=$(docker run --rm --entrypoint="/bin/sh" "$DOCKER_IMAGE_TAG" -c "kubectl version --client --short 2>/dev/null || echo 'error'"); then
        if [[ "$kubectl_version" != "error" ]]; then
            log_message "INFO" "  ✓ kubectl: $kubectl_version"
        else
            log_message "FAIL" "  ✗ kubectl version check failed"
            return 1
        fi
    fi
    
    # Test helm version
    local helm_version
    if helm_version=$(docker run --rm --entrypoint="/bin/sh" "$DOCKER_IMAGE_TAG" -c "helm version --short 2>/dev/null || echo 'error'"); then
        if [[ "$helm_version" != "error" ]]; then
            log_message "INFO" "  ✓ Helm: $helm_version"
        else
            log_message "FAIL" "  ✗ Helm version check failed"
            return 1
        fi
    fi
    
    # Test AWS CLI version
    local aws_version
    if aws_version=$(docker run --rm --entrypoint="/bin/sh" "$DOCKER_IMAGE_TAG" -c "aws --version 2>/dev/null || echo 'error'"); then
        if [[ "$aws_version" != "error" ]]; then
            log_message "INFO" "  ✓ AWS CLI: $aws_version"
        else
            log_message "FAIL" "  ✗ AWS CLI version check failed"
            return 1
        fi
    fi
    
    log_message "PASS" "$test_name"
}

test_dry_run_mode() {
    local test_name="Dry Run Mode"
    
    log_message "INFO" "Testing dry run mode..."
    
    local output
    if output=$(docker run --rm \
        -e INPUT_CLUSTER_NAME="$TEST_CLUSTER_NAME" \
        -e INPUT_REGION="$TEST_REGION" \
        -e INPUT_DRY_RUN="true" \
        -e INPUT_ARGS="echo 'test command'" \
        "$DOCKER_IMAGE_TAG" 2>&1); then
        
        if echo "$output" | grep -q "DRY RUN MODE"; then
            log_message "PASS" "$test_name"
        else
            log_message "FAIL" "$test_name" "Dry run mode not detected"
            echo "Output:"
            echo "$output"
            return 1
        fi
    else
        log_message "FAIL" "$test_name" "Dry run execution failed"
        echo "Output:"
        echo "$output"
        return 1
    fi
}

test_error_handling() {
    local test_name="Error Handling"
    
    log_message "INFO" "Testing error handling..."
    
    # Test missing cluster name
    local output
    if output=$(docker run --rm \
        -e INPUT_REGION="$TEST_REGION" \
        -e INPUT_ARGS="echo 'test'" \
        "$DOCKER_IMAGE_TAG" 2>&1); then
        
        # Should fail with missing cluster name
        log_message "FAIL" "$test_name" "Should have failed with missing cluster name"
        return 1
    else
        if echo "$output" | grep -q "CLUSTER_NAME is required"; then
            log_message "PASS" "$test_name"
        else
            log_message "FAIL" "$test_name" "Did not produce expected error for missing cluster-name"
            echo "Output:"
            echo "$output"
            return 1
        fi
    fi
}

test_health_check() {
    local test_name="Health Check"
    
    log_message "INFO" "Testing health check script..."
    
    # Test health check script directly
    local output
    if output=$(docker run --rm \
        --entrypoint="/health-check.sh" \
        "$DOCKER_IMAGE_TAG" 2>&1); then
        log_message "PASS" "$test_name"
    else
        log_message "FAIL" "$test_name" "Health check script failed"
        echo "Health check output:"
        echo "$output"
        return 1
    fi
}

test_template_validation() {
    local test_name="Template Validation"
    
    log_message "INFO" "Testing configuration templates..."
    
    # Test that templates exist and have required variables
    local output
    if output=$(docker run --rm \
        --entrypoint="/bin/sh" \
        "$DOCKER_IMAGE_TAG" \
        -c "ls -la /config.template /private-config.template 2>/dev/null || echo 'templates missing'" 2>&1); then
        
        if echo "$output" | grep -q "templates missing"; then
            log_message "FAIL" "$test_name" "Configuration templates missing"
            return 1
        else
            log_message "PASS" "$test_name"
        fi
    else
        log_message "FAIL" "$test_name" "Template validation failed"
        return 1
    fi
}

test_script_permissions() {
    local test_name="Script Permissions"
    
    log_message "INFO" "Testing script permissions..."
    
    local scripts=("/entrypoint.sh" "/health-check.sh" "/setup-tools.sh" "/cleanup.sh")
    local all_executable=true
    
    for script in "${scripts[@]}"; do
        if docker run --rm --entrypoint="/bin/sh" "$DOCKER_IMAGE_TAG" -c "test -x $script" 2>/dev/null; then
            log_message "INFO" "  ✓ $script is executable"
        else
            log_message "FAIL" "  ✗ $script is not executable"
            all_executable=false
        fi
    done
    
    if [[ "$all_executable" == "true" ]]; then
        log_message "PASS" "$test_name"
    else
        log_message "FAIL" "$test_name" "Some scripts are not executable"
        return 1
    fi
}

cleanup_test_images() {
    log_message "INFO" "Cleaning up test images..."
    
    # Remove test image if it exists
    if docker images "$DOCKER_IMAGE_TAG" --format "table {{.Repository}}:{{.Tag}}" | grep -q "$DOCKER_IMAGE_TAG"; then
        if docker rmi "$DOCKER_IMAGE_TAG" >/dev/null 2>&1; then
            log_message "INFO" "Test image removed: $DOCKER_IMAGE_TAG"
        else
            log_message "WARN" "Failed to remove test image: $DOCKER_IMAGE_TAG"
        fi
    fi
}

main() {
    log_message "INFO" "=== EKS Helm Client Integration Tests ===" "Starting tests"
    
    # Set up cleanup on exit
    trap cleanup_test_images EXIT
    
    # Check prerequisites
    check_prerequisites
    
    # Run tests in order
    test_docker_build || exit 1
    test_container_startup
    test_tools_availability
    test_tool_versions
    test_dry_run_mode
    test_error_handling
    test_health_check
    test_template_validation
    test_script_permissions
    
    log_message "INFO" "=== Test Results Summary ==="
    echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
    echo -e "${RED}Failed:${NC} $TESTS_FAILED"
    echo -e "${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        log_message "FAIL" "Integration tests failed!"
        exit 1
    else
        log_message "PASS" "All integration tests passed!"
    fi
}

main