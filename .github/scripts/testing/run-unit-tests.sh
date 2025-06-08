#!/bin/bash
# .github/scripts/testing/run-unit-tests.sh

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

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_pass() {
    echo -e "${GREEN}✓${NC} $1" >&2
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}✗${NC} $1" >&2
    ((TESTS_FAILED++))
}

setup_test_env() {
    log_info "Setting up test environment..."
    export TEST_DIR="/tmp/eks-helm-test-$$"
    
    if ! mkdir -p "$TEST_DIR"; then
        log_fail "Failed to create test directory: $TEST_DIR"
        exit 1
    fi
    
    trap cleanup_test_env EXIT
    log_info "Test environment ready: $TEST_DIR"
}

cleanup_test_env() {
    if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
        log_info "Cleaning up test environment: $TEST_DIR"
        rm -rf "$TEST_DIR" 2>/dev/null || true
    fi
}

test_script_permissions() {
    local test_name="Script Permissions"
    log_info "Running test: $test_name"
    
    local scripts=("scripts/entrypoint.sh" "scripts/setup-tools.sh" "scripts/health-check.sh" "scripts/cleanup.sh")
    local all_executable=true
    
    for script in "${scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            log_info "✗ $script not found"
            all_executable=false
        elif [[ ! -x "$script" ]]; then
            log_info "✗ $script not executable"
            all_executable=false
        else
            log_info "✓ $script is executable"
        fi
    done
    
    if [[ "$all_executable" == "true" ]]; then
        log_pass "$test_name"
    else
        log_fail "$test_name"
    fi
}

test_required_files() {
    local test_name="Required Files"
    log_info "Running test: $test_name"
    
    local files=("action.yml" "Dockerfile" "README.md" "LICENSE.md")
    local all_exist=true
    
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_info "✗ $file not found"
            all_exist=false
        else
            log_info "✓ $file exists"
        fi
    done
    
    if [[ "$all_exist" == "true" ]]; then
        log_pass "$test_name"
    else
        log_fail "$test_name"
    fi
}

test_dockerfile_syntax() {
    local test_name="Dockerfile Syntax"
    log_info "Running test: $test_name"
    
    if [[ ! -f "Dockerfile" ]]; then
        log_info "✗ Dockerfile not found"
        log_fail "$test_name"
        return
    fi
    
    local has_from=false
    local has_entrypoint=false
    
    if grep -q "^FROM " Dockerfile; then
        log_info "✓ Dockerfile has FROM instruction"
        has_from=true
    else
        log_info "✗ Dockerfile missing FROM instruction"
    fi
    
    if grep -q "^ENTRYPOINT " Dockerfile || grep -q "^CMD " Dockerfile; then
        log_info "✓ Dockerfile has entry point"
        has_entrypoint=true
    else
        log_info "✗ Dockerfile missing ENTRYPOINT or CMD instruction"
    fi
    
    if [[ "$has_from" == "true" && "$has_entrypoint" == "true" ]]; then
        log_pass "$test_name"
    else
        log_fail "$test_name"
    fi
}

test_action_yml_syntax() {
    local test_name="action.yml Syntax"
    log_info "Running test: $test_name"
    
    if [[ ! -f "action.yml" ]]; then
        log_info "✗ action.yml not found"
        log_fail "$test_name"
        return
    fi
    
    local all_present=true
    
    # Check required fields
    if grep -q "^name:" action.yml; then
        log_info "✓ action.yml has name field"
    else
        log_info "✗ action.yml missing name field"
        all_present=false
    fi
    
    if grep -q "^description:" action.yml; then
        log_info "✓ action.yml has description field"
    else
        log_info "✗ action.yml missing description field"
        all_present=false
    fi
    
    if grep -q "^runs:" action.yml; then
        log_info "✓ action.yml has runs field"
    else
        log_info "✗ action.yml missing runs field"
        all_present=false
    fi
    
    # Check Docker configuration
    if grep -q "using: 'docker'" action.yml && grep -q "image: 'Dockerfile'" action.yml; then
        log_info "✓ action.yml configured for Docker"
    else
        log_info "✗ action.yml Docker configuration invalid"
        all_present=false
    fi
    
    if [[ "$all_present" == "true" ]]; then
        log_pass "$test_name"
    else
        log_fail "$test_name"
    fi
}

test_template_files() {
    local test_name="Template Files"
    log_info "Running test: $test_name"
    
    local templates=("templates/config.template" "templates/private-config.template")
    local all_valid=true
    
    for template in "${templates[@]}"; do
        if [[ ! -f "$template" ]]; then
            log_info "✗ $template not found"
            all_valid=false
            continue
        fi
        
        if grep -q '\${CLUSTER_NAME}' "$template" && grep -q '\${REGION_CODE}' "$template"; then
            log_info "✓ $template has required variables"
        else
            log_info "✗ $template missing required variables"
            all_valid=false
        fi
    done
    
    if [[ "$all_valid" == "true" ]]; then
        log_pass "$test_name"
    else
        log_fail "$test_name"
    fi
}

main() {
    log_info "=== EKS Helm Client Unit Tests ==="
    
    # Setup test environment
    setup_test_env
    
    # Run all tests
    test_script_permissions
    test_required_files
    test_dockerfile_syntax
    test_action_yml_syntax
    test_template_files
    
    # Print summary
    echo ""
    echo -e "${BLUE}=== Test Results Summary ===${NC}" >&2
    echo -e "${GREEN}Passed:${NC} $TESTS_PASSED" >&2
    echo -e "${RED}Failed:${NC} $TESTS_FAILED" >&2
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}[FAIL]${NC} Unit tests failed! ($TESTS_FAILED failures)" >&2
        exit 1
    else
        echo -e "${GREEN}[PASS]${NC} All unit tests passed! ($TESTS_PASSED tests)" >&2
        exit 0
    fi
}

# Disable 'set -e' for the main function to handle errors manually
set +e
main
exit_code=$?
set -e
exit $exit_code