#!/bin/bash
# .github/scripts/testing/run-unit-tests.sh
# Run unit tests for the EKS Helm Client GitHub Action

set -e

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test results log
TEST_RESULTS=""

# Function to log test results
log_test() {
    local test_name=$1
    local status=$2
    local message=${3:-""}
    
    case $status in
        "PASS")
            echo -e "${GREEN}✓${NC} $test_name"
            ((TESTS_PASSED++))
            TEST_RESULTS="${TEST_RESULTS}\n✓ $test_name"
            ;;
        "FAIL")
            echo -e "${RED}✗${NC} $test_name: $message"
            ((TESTS_FAILED++))
            TEST_RESULTS="${TEST_RESULTS}\n✗ $test_name: $message"
            ;;
        "SKIP")
            echo -e "${YELLOW}○${NC} $test_name: $message"
            ((TESTS_SKIPPED++))
            TEST_RESULTS="${TEST_RESULTS}\n○ $test_name: $message"
            ;;
    esac
}

# Function to setup test environment
setup_test_env() {
    echo -e "${BLUE}Setting up test environment...${NC}"
    
    # Create temporary directories
    export TEST_DIR="/tmp/eks-helm-test-$$"
    export TEST_KUBECONFIG="$TEST_DIR/kubeconfig"
    export TEST_HELM_HOME="$TEST_DIR/helm"
    
    mkdir -p "$TEST_DIR" "$TEST_HELM_HOME"
    
    # Set test environment variables
    export KUBECONFIG="$TEST_KUBECONFIG"
    export HELM_HOME="$TEST_HELM_HOME"
    export INPUT_DEBUG="true"
    export INPUT_DRY_RUN="true"
}

# Function to cleanup test environment
cleanup_test_env() {
    if [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

# Test: Script permissions
test_script_permissions() {
    local test_name="Script Permissions"
    local scripts=(
        "scripts/entrypoint.sh"
        "scripts/health-check.sh"
        "scripts/setup-tools.sh"
        "scripts/cleanup.sh"
    )
    
    local all_executable=true
    for script in "${scripts[@]}"; do
        if [[ ! -x "$script" ]]; then
            log_test "$test_name - $script" "FAIL" "Not executable"
            all_executable=false
        fi
    done
    
    if [[ "$all_executable" == "true" ]]; then
        log_test "$test_name" "PASS"
    fi
}

# Test: Required files exist
test_required_files() {
    local test_name="Required Files"
    local files=(
        "action.yml"
        "Dockerfile"
        "templates/config.template"
        "templates/private-config.template"
    )
    
    local all_exist=true
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_test "$test_name - $file" "FAIL" "File not found"
            all_exist=false
        fi
    done
    
    if [[ "$all_exist" == "true" ]]; then
        log_test "$test_name" "PASS"
    fi
}

# Test: Dockerfile syntax
test_dockerfile_syntax() {
    local test_name="Dockerfile Syntax"
    
    if command -v docker >/dev/null 2>&1; then
        if docker build --no-cache -f Dockerfile -t test-syntax-check:latest . >/dev/null 2>&1; then
            log_test "$test_name" "PASS"
            docker rmi test-syntax-check:latest >/dev/null 2>&1 || true
        else
            log_test "$test_name" "FAIL" "Dockerfile build failed"
        fi
    else
        log_test "$test_name" "SKIP" "Docker not available"
    fi
}

# Test: action.yml validation
test_action_yml() {
    local test_name="action.yml Validation"
    
    # Check required fields
    local required_fields=("name" "description" "runs")
    local all_fields_present=true
    
    for field in "${required_fields[@]}"; do
        if ! grep -q "^$field:" action.yml; then
            log_test "$test_name - $field" "FAIL" "Required field missing"
            all_fields_present=false
        fi
    done
    
    # Check runs.using is 'docker'
    if ! grep -q "using: 'docker'" action.yml; then
        log_test "$test_name - runs.using" "FAIL" "Must use docker"
        all_fields_present=false
    fi
    
    if [[ "$all_fields_present" == "true" ]]; then
        log_test "$test_name" "PASS"
    fi
}

# Test: Template variable validation
test_template_variables() {
    local test_name="Template Variables"
    
    # Check config.template
    local config_vars=(
        "ENDPOINT_URL"
        "CA_CERT"
        "CLUSTER_NAME"
        "REGION_CODE"
    )
    
    local all_vars_present=true
    for var in "${config_vars[@]}"; do
        if ! grep -q "\${$var" templates/config.template; then
            log_test "$test_name - config.template - $var" "FAIL" "Variable not found"
            all_vars_present=false
        fi
    done
    
    # Check private-config.template
    if ! grep -q "\${VPC_ID" templates/private-config.template; then
        log_test "$test_name - private-config.template" "FAIL" "VPC_ID variable not found"
        all_vars_present=false
    fi
    
    if [[ "$all_vars_present" == "true" ]]; then
        log_test "$test_name" "PASS"
    fi
}

# Test: Script syntax check
test_script_syntax() {
    local test_name="Script Syntax"
    local scripts=(
        "scripts/entrypoint.sh"
        "scripts/health-check.sh"
        "scripts/setup-tools.sh"
        "scripts/cleanup.sh"
    )
    
    local all_valid=true
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            if ! bash -n "$script" 2>/dev/null; then
                log_test "$test_name - $script" "FAIL" "Syntax error"
                all_valid=false
            fi
        fi
    done
    
    if [[ "$all_valid" == "true" ]]; then
        log_test "$test_name" "PASS"
    fi
}

# Test: Environment variable handling
test_env_var_handling() {
    local test_name="Environment Variable Handling"
    
    # Create a test script to check env var handling
    cat > "$TEST_DIR/test-env.sh" << 'EOF'
#!/bin/bash
source scripts/entrypoint.sh 2>/dev/null || true

# Test default values
if [[ -z "$KUBECTL_VERSION" ]]; then
    exit 1
fi

if [[ -z "$HELM_VERSION" ]]; then
    exit 1
fi

echo "PASS"
EOF
    
    chmod +x "$TEST_DIR/test-env.sh"
    
    if output=$("$TEST_DIR/test-env.sh" 2>&1); then
        if [[ "$output" == "PASS" ]]; then
            log_test "$test_name" "PASS"
        else
            log_test "$test_name" "FAIL" "Unexpected output"
        fi
    else
        log_test "$test_name" "FAIL" "Script execution failed"
    fi
}

# Test: Security checks
test_security_checks() {
    local test_name="Security Checks"
    
    # Check for hardcoded secrets
    if grep -r "password\|secret\|key" scripts/ | grep -v "INPUT_.*PASSWORD\|INPUT_.*SECRET" | grep -v "^#" >/dev/null 2>&1; then
        log_test "$test_name - Hardcoded Secrets" "FAIL" "Potential hardcoded secrets found"
    else
        log_test "$test_name - No Hardcoded Secrets" "PASS"
    fi
    
    # Check for proper cleanup in scripts
    if grep -q "cleanup" scripts/entrypoint.sh && grep -q "trap.*cleanup" scripts/entrypoint.sh; then
        log_test "$test_name - Cleanup Trap" "PASS"
    else
        log_test "$test_name - Cleanup Trap" "FAIL" "No cleanup trap found"
    fi
}

# Test: Input parameter validation
test_input_validation() {
    local test_name="Input Validation"
    
    # Check if action.yml has all documented inputs
    local inputs=(
        "args"
        "cluster-name"
        "region"
        "private-cluster"
        "kubectl-version"
        "helm-version"
        "debug"
        "dry-run"
    )
    
    local all_inputs_defined=true
    for input in "${inputs[@]}"; do
        if ! grep -A1 "  $input:" action.yml >/dev/null 2>&1; then
            log_test "$test_name - $input" "FAIL" "Input not defined in action.yml"
            all_inputs_defined=false
        fi
    done
    
    if [[ "$all_inputs_defined" == "true" ]]; then
        log_test "$test_name" "PASS"
    fi
}

# Test: Error handling
test_error_handling() {
    local test_name="Error Handling"
    
    # Check for set -e in scripts
    local scripts=(
        "scripts/entrypoint.sh"
        "scripts/health-check.sh"
        "scripts/setup-tools.sh"
        "scripts/cleanup.sh"
    )
    
    local all_have_error_handling=true
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            if ! grep -q "^set -e" "$script"; then
                log_test "$test_name - $script" "FAIL" "Missing 'set -e'"
                all_have_error_handling=false
            fi
        fi
    done
    
    if [[ "$all_have_error_handling" == "true" ]]; then
        log_test "$test_name" "PASS"
    fi
}

# Test: Container health check
test_health_check_script() {
    local test_name="Health Check Script"
    
    if [[ -f "scripts/health-check.sh" ]]; then
        # Test that health check has proper exit codes
        if grep -q "HEALTH_OK=0" scripts/health-check.sh && grep -q "HEALTH_ERROR=1" scripts/health-check.sh; then
            log_test "$test_name - Exit Codes" "PASS"
        else
            log_test "$test_name - Exit Codes" "FAIL" "Missing proper exit codes"
        fi
        
        # Test that health check has timeout
        if grep -q "HEALTH_TIMEOUT" scripts/health-check.sh; then
            log_test "$test_name - Timeout" "PASS"
        else
            log_test "$test_name - Timeout" "FAIL" "Missing timeout handling"
        fi
    else
        log_test "$test_name" "FAIL" "Health check script not found"
    fi
}

# Main test execution
main() {
    echo -e "${BLUE}=== EKS Helm Client Unit Tests ===${NC}"
    echo -e "${BLUE}Running unit tests...${NC}\n"
    
    # Setup test environment
    setup_test_env
    
    # Run all tests
    test_script_permissions
    test_required_files
    test_dockerfile_syntax
    test_action_yml
    test_template_variables
    test_script_syntax
    test_env_var_handling
    test_security_checks
    test_input_validation
    test_error_handling
    test_health_check_script
    
    # Display results summary
    echo -e "\n${BLUE}=== Test Results Summary ===${NC}"
    echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
    echo -e "${RED}Failed:${NC} $TESTS_FAILED"
    echo -e "${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
    echo -e "${BLUE}Total:${NC} $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
    
    # Save test results
    echo -e "Test Results:\n$TEST_RESULTS" > "$TEST_DIR/test-results.txt"
    
    # Cleanup
    cleanup_test_env
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "\n${RED}Unit tests failed!${NC}"
        exit 1
    else
        echo -e "\n${GREEN}All unit tests passed!${NC}"
        exit 0
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi