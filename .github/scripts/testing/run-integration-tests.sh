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
}

test_docker_build() {
    local test_name="Docker Image Build"
    log_message "INFO" "Building Docker image..."
    
    if output=$(docker build -t "$DOCKER_IMAGE_TAG" . 2>&1); then
        log_message "PASS" "$test_name"
    else
        log_message "FAIL" "$test_name" "Docker build failed. See output below."
        echo -e "\n--- Docker Build Output ---\n$output\n---------------------------\n"
        return 1
    fi
}

test_container_startup() {
    local test_name="Container Startup"
    local output
    
    output=$(docker run --rm \
        -e INPUT_CLUSTER_NAME="$TEST_CLUSTER_NAME" \
        -e INPUT_REGION="$TEST_REGION" \
        -e INPUT_DRY_RUN="true" \
        -e INPUT_ARGS="echo 'Container started successfully'" \
        "$DOCKER_IMAGE_TAG" 2>&1)
        
    if [[ $? -eq 0 ]]; then
        log_message "PASS" "$test_name"
    else
        log_message "FAIL" "$test_name" "Container failed to start. See output below."
        echo -e "\n--- Container Startup Output ---\n$output\n------------------------------\n"
    fi
}

test_tools_availability() {
    local test_name="Tools Availability"
    local tools=("kubectl" "helm" "aws" "eksctl" "jq")
    local all_available=true
    
    for tool in "${tools[@]}"; do
        if docker run --rm --entrypoint "/bin/sh" "$DOCKER_IMAGE_TAG" -c "command -v $tool" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} $tool available"
        else
            echo -e "  ${RED}✗${NC} $tool not available"
            all_available=false
        fi
    done
    
    if [[ "$all_available" == "true" ]]; then
        log_message "PASS" "$test_name"
    else
        log_message "FAIL" "$test_name" "Some required tools are missing in the container"
    fi
}

test_dry_run_mode() {
    local test_name="Dry Run Mode"
    local output
    
    output=$(docker run --rm \
        -e INPUT_CLUSTER_NAME="$TEST_CLUSTER_NAME" \
        -e INPUT_REGION="$TEST_REGION" \
        -e INPUT_DRY_RUN="true" \
        -e INPUT_ARGS="helm install test-chart bitnami/nginx" \
        "$DOCKER_IMAGE_TAG" 2>&1)
    
    if echo "$output" | grep -q "DRY RUN MODE"; then
        log_message "PASS" "$test_name"
    else
        log_message "FAIL" "$test_name" "'DRY RUN MODE' banner not found in output"
        echo -e "\n--- Dry Run Output ---\n$output\n----------------------\n"
    fi
}

test_error_handling() {
    local test_name="Error Handling (Missing Inputs)"
    local output
    
    output=$(docker run --rm \
        -e INPUT_ARGS="echo 'test'" \
        "$DOCKER_IMAGE_TAG" 2>&1)
        
    if echo "$output" | grep -q "Input 'cluster-name' is required"; then
        log_message "PASS" "$test_name"
    else
        log_message "FAIL" "$test_name" "Did not produce expected error for missing cluster-name"
        echo -e "\n--- Error Handling Output ---\n$output\n---------------------------\n"
    fi
}

main() {
    log_message "INFO" "=== EKS Helm Client Integration Tests ===" "Starting tests"
    
    check_prerequisites
    
    # The 'test_docker_build' function will cause the script to exit if it fails
    # because of 'set -e' and the 'return 1' on failure.
    test_docker_build || exit 1
    
    test_container_startup
    test_tools_availability
    test_dry_run_mode
    test_error_handling
    
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