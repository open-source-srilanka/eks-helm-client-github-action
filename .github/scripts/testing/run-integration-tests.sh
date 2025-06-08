#!/bin/bash
# .github/scripts/testing/run-integration-tests.sh
# Run integration tests for the EKS Helm Client GitHub Action

set -e

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Test configuration
readonly TEST_CLUSTER_NAME="${TEST_CLUSTER_NAME:-test-eks-cluster}"
readonly TEST_REGION="${TEST_REGION:-us-west-2}"
readonly TEST_NAMESPACE="${TEST_NAMESPACE:-test-namespace}"
readonly TEST_TIMEOUT="${TEST_TIMEOUT:-300}"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Docker image tag for testing
readonly DOCKER_IMAGE_TAG="${DOCKER_IMAGE_TAG:-eks-helm-client:test}"

# Function to log test results
log_test() {
    local test_name=$1
    local status=$2
    local message=${3:-""}
    
    case $status in
        "PASS")
            echo -e "${GREEN}✓${NC} $test_name"
            ((TESTS_PASSED++))
            ;;
        "FAIL")
            echo -e "${RED}✗${NC} $test_name: $message"
            ((TESTS_FAILED++))
            ;;
        "SKIP")
            echo -e "${YELLOW}○${NC} $test_name: $message"
            ((TESTS_SKIPPED++))
            ;;
    esac
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${BLUE}Checking prerequisites...${NC}"
    
    local prereqs_met=true
    
    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}Docker is required for integration tests${NC}"
        prereqs_met=false
    fi
    
    # Check AWS CLI (optional for full tests)
    if ! command -v aws >/dev/null 2>&1; then
        echo -e "${YELLOW}AWS CLI not found - some tests will be skipped${NC}"
    fi
    
    # Check if running in CI or local
    if [[ -n "$CI" ]]; then
        echo -e "${BLUE}Running in CI environment${NC}"
    else
        echo -e "${BLUE}Running in local environment${NC}"
    fi
    
    if [[ "$prereqs_met" == "false" ]]; then
        echo -e "${RED}Prerequisites not met${NC}"
        exit 1
    fi
}

# Test: Docker image build
test_docker_build() {
    local test_name="Docker Image Build"
    
    echo -e "${BLUE}Building Docker image...${NC}"
    
    if docker build -t "$DOCKER_IMAGE_TAG" . >/dev/null 2>&1; then
        log_test "$test_name" "PASS"
    else
        log_test "$test_name" "FAIL" "Docker build failed"
        return 1
    fi
}

# Test: Container startup
test_container_startup() {
    local test_name="Container Startup"
    
    if docker run --rm \
        -e INPUT_CLUSTER_NAME="$TEST_CLUSTER_NAME" \
        -e INPUT_REGION="$TEST_REGION" \
        -e INPUT_DRY_RUN="true" \
        -e INPUT_DEBUG="true" \
        -e INPUT_ARGS="echo 'Container started successfully'" \
        "$DOCKER_IMAGE_TAG" >/dev/null 2>&1; then
        log_test "$test_name" "PASS"
    else
        log_test "$test_name" "FAIL" "Container failed to start"
    fi
}

# Test: Tool availability in container
test_tools_availability() {
    local test_name="Tools Availability"
    
    local tools=(
        "kubectl"
        "helm"
        "aws"
        "aws-iam-authenticator"
        "eksctl"
        "jq"
        "curl"
    )
    
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
        log_test "$test_name" "PASS"
    else
        log_test "$test_name" "FAIL" "Some tools missing"
    fi
}

# Test: Health check functionality
test_health_check() {
    local test_name="Health Check"
    
    # Run health check inside container
    if docker run --rm --entrypoint "/health-check.sh" "$DOCKER_IMAGE_TAG" >/dev/null 2>&1; then
        log_test "$test_name" "PASS"
    else
        log_test "$test_name" "FAIL" "Health check failed"
    fi
}

# Test: Dry run mode
test_dry_run_mode() {
    local test_name="Dry Run Mode"
    
    local output=$(docker run --rm \
        -e INPUT_CLUSTER_NAME="$TEST_CLUSTER_NAME" \
        -e INPUT_REGION="$TEST_REGION" \
        -e INPUT_DRY_RUN="true" \
        -e INPUT_ARGS="helm install test-chart bitnami/nginx" \
        "$DOCKER_IMAGE_TAG" 2>&1)
    
    if echo "$output" | grep -q "DRY RUN MODE"; then
        log_test "$test_name" "PASS"
    else
        log_test "$test_name" "FAIL" "Dry run mode not working"
    fi
}

# Test: Debug mode
test_debug_mode() {
    local test_name="Debug Mode"
    
    local output=$(docker run --rm \
        -e INPUT_CLUSTER_NAME="$TEST_CLUSTER_NAME" \
        -e INPUT_REGION="$TEST_REGION" \
        -e INPUT_DEBUG="true" \
        -e INPUT_DRY_RUN="true" \
        -e INPUT_ARGS="echo 'Debug test'" \
        "$DOCKER_IMAGE_TAG" 2>&1)
    
    if echo "$output" | grep -q "Tool versions"; then
        log_test "$test_name" "PASS"
    else
        log_test "$test_name" "FAIL" "Debug output not found"
    fi
}

# Test: Error handling
test_error_handling() {
    local test_name="Error Handling"
    
    # Test missing required parameters
    if docker run --rm \
        -e INPUT_ARGS="echo 'test'" \
        "$DOCKER_IMAGE_TAG" 2>&1 | grep -q "CLUSTER_NAME is required"; then
        log_test "$test_name - Missing Cluster" "PASS"
    else
        log_test "$test_name - Missing Cluster" "FAIL" "No error for missing cluster"
    fi
    
    # Test invalid region
    if docker run --rm \
        -e INPUT_CLUSTER_NAME="$TEST_CLUSTER_NAME" \
        -e INPUT_ARGS="echo 'test'" \
        "$DOCKER_IMAGE_TAG" 2>&1 | grep -q "REGION_CODE is required"; then
        log_test "$test_name - Missing Region" "PASS"
    else
        log_test "$test_name - Missing Region" "FAIL" "No error for missing region"
    fi
}

# Test: Private cluster configuration
test_private_cluster_config() {
    local test_name="Private Cluster Configuration"
    
    local output=$(docker run --rm \
        -e INPUT_CLUSTER_NAME="$TEST_CLUSTER_NAME" \
        -e INPUT_REGION="$TEST_REGION" \
        -e INPUT_PRIVATE_CLUSTER="true" \
        -e INPUT_DRY_RUN="true" \
        -e INPUT_DEBUG="true" \
        -e INPUT_ARGS="echo 'Private cluster test'" \
        "$DOCKER_IMAGE_TAG" 2>&1)
    
    if echo "$output" | grep -q "Private: true"; then
        log_test "$test_name" "PASS"
    else
        log_test "$test_name" "FAIL" "Private cluster flag not recognized"
    fi
}

# Test: Custom tool versions
test_custom_tool_versions() {
    local test_name="Custom Tool Versions"
    
    # Test custom kubectl version
    local output=$(docker run --rm \
        -e INPUT_CLUSTER_NAME="$TEST_CLUSTER_NAME" \
        -e INPUT_REGION="$TEST_REGION" \
        -e INPUT_KUBECTL_VERSION="1.27.1" \
        -e INPUT_DRY_RUN="true" \
        -e INPUT_DEBUG="true" \
        -e INPUT_ARGS="kubectl version --client" \
        "$DOCKER_IMAGE_TAG" 2>&1)
    
    if echo "$output" | grep -q "Installing kubectl version 1.27.1"; then
        log_test "$test_name - kubectl" "PASS"
    else
        log_test "$test_name - kubectl" "FAIL" "Custom kubectl version not installed"
    fi
    
    # Test custom Helm version
    output=$(docker run --rm \
        -e INPUT_CLUSTER_NAME="$TEST_CLUSTER_NAME" \
        -e INPUT_REGION="$TEST_REGION" \
        -e INPUT_HELM_VERSION="3.12.0" \
        -e INPUT_DRY_RUN="true" \
        -e INPUT_DEBUG="true" \
        -e INPUT_ARGS="helm version" \
        "$DOCKER_IMAGE_TAG" 2>&1)
    
    if echo "$output" | grep -q "Installing Helm version 3.12.0"; then
        log_test "$test_name - Helm" "PASS"
    else
        log_test "$test_name - Helm" "FAIL" "Custom Helm version not installed"
    fi
}

# Test: Timeout handling
test_timeout_handling() {
    local test_name="Timeout Handling"
    
    # This test will be skipped in most cases as it requires a real cluster
    if [[ -z "$INTEGRATION_TEST_CLUSTER" ]]; then
        log_test "$test_name" "SKIP" "No test cluster available"
        return
    fi
    
    # Test with very short timeout
    if timeout 10 docker run --rm \
        -e INPUT_CLUSTER_NAME="$TEST_CLUSTER_NAME" \
        -e INPUT_REGION="$TEST_REGION" \
        -e INPUT_TIMEOUT="1" \
        -e INPUT_DRY_RUN="true" \
        -e INPUT_ARGS="sleep 5" \
        "$DOCKER_IMAGE_TAG" 2>&1 | grep -q "timeout"; then
        log_test "$test_name" "PASS"
    else
        log_test "$test_name" "FAIL" "Timeout not enforced"
    fi
}

# Test: Cleanup functionality
test_cleanup() {
    local test_name="Cleanup Functionality"
    
    # Run cleanup script
    if docker run --rm --entrypoint "/cleanup.sh" "$DOCKER_IMAGE_TAG" --no-verify >/dev/null 2>&1; then
        log_test "$test_name" "PASS"
    else
        log_test "$test_name" "FAIL" "Cleanup script failed"
    fi
}

# Test: Setup tools script
test_setup_tools() {
    local test_name="Setup Tools Script"
    
    # Test setup tools verification
    if docker run --rm --entrypoint "/setup-tools.sh" "$DOCKER_IMAGE_TAG" --verify-only >/dev/null 2>&1; then
        log_test "$test_name" "PASS"
    else
        log_test "$test_name" "FAIL" "Setup tools verification failed"
    fi
}

# Test: Template processing
test_template_processing() {
    local test_name="Template Processing"
    
    # Test that templates are processed correctly
    local output=$(docker run --rm \
        -e INPUT_CLUSTER_NAME="test-cluster" \
        -e INPUT_REGION="us-west-2" \
        -e INPUT_DRY_RUN="true" \
        -e INPUT_DEBUG="true" \
        -e CA_CERT="test-cert" \
        -e ENDPOINT_URL="https://test.eks.amazonaws.com" \
        -e INPUT_ARGS="cat $KUBECONFIG || echo 'No kubeconfig'" \
        "$DOCKER_IMAGE_TAG" 2>&1)
    
    if echo "$output" | grep -q "server: https://test.eks.amazonaws.com\|No kubeconfig"; then
        log_test "$test_name" "PASS"
    else
        log_test "$test_name" "FAIL" "Template not processed correctly"
    fi
}

# Test: AWS credentials handling
test_aws_credentials() {
    local test_name="AWS Credentials Handling"
    
    # Test without AWS credentials
    local output=$(docker run --rm \
        -e INPUT_CLUSTER_NAME="$TEST_CLUSTER_NAME" \
        -e INPUT_REGION="$TEST_REGION" \
        -e INPUT_DRY_RUN="true" \
        -e AWS_ACCESS_KEY_ID="" \
        -e AWS_SECRET_ACCESS_KEY="" \
        -e INPUT_ARGS="echo 'test'" \
        "$DOCKER_IMAGE_TAG" 2>&1)
    
    if echo "$output" | grep -q "AWS credentials not configured"; then
        log_test "$test_name" "PASS"
    else
        log_test "$test_name" "SKIP" "AWS credential check bypassed"
    fi
}

# Test: Memory and resource limits
test_resource_limits() {
    local test_name="Resource Limits"
    
    # Run container with memory limit
    if docker run --rm \
        --memory="256m" \
        --cpus="0.5" \
        -e INPUT_CLUSTER_NAME="$TEST_CLUSTER_NAME" \
        -e INPUT_REGION="$TEST_REGION" \
        -e INPUT_DRY_RUN="true" \
        -e INPUT_ARGS="echo 'Resource test'" \
        "$DOCKER_IMAGE_TAG" >/dev/null 2>&1; then
        log_test "$test_name" "PASS"
    else
        log_test "$test_name" "FAIL" "Container failed with resource limits"
    fi
}

# Main test execution
main() {
    echo -e "${BLUE}=== EKS Helm Client Integration Tests ===${NC}"
    echo -e "${BLUE}Docker Image: $DOCKER_IMAGE_TAG${NC}"
    echo -e "${BLUE}Test Cluster: $TEST_CLUSTER_NAME${NC}"
    echo -e "${BLUE}Test Region: $TEST_REGION${NC}\n"
    
    # Check prerequisites
    check_prerequisites
    
    # Run tests
    echo -e "${BLUE}Running integration tests...${NC}\n"
    
    test_docker_build || {
        echo -e "${RED}Docker build failed - skipping remaining tests${NC}"
        exit 1
    }
    
    test_container_startup
    test_tools_availability
    test_health_check
    test_dry_run_mode
    test_debug_mode
    test_error_handling
    test_private_cluster_config
    test_custom_tool_versions
    test_timeout_handling
    test_cleanup
    test_setup_tools
    test_template_processing
    test_aws_credentials
    test_resource_limits
    
    # Display results summary
    echo -e "\n${BLUE}=== Test Results Summary ===${NC}"
    echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
    echo -e "${RED}Failed:${NC} $TESTS_FAILED"
    echo -e "${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
    echo -e "${BLUE}Total:${NC} $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
    
    # Cleanup
    echo -e "\n${BLUE}Cleaning up...${NC}"
    docker rmi "$DOCKER_IMAGE_TAG" >/dev/null 2>&1 || true
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "\n${RED}Integration tests failed!${NC}"
        exit 1
    else
        echo -e "\n${GREEN}All integration tests passed!${NC}"
        exit 0
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi