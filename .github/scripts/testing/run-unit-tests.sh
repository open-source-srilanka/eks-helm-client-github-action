#!/bin/bash
# .github/scripts/testing/run-unit-tests.sh

set -e

# Source shared testing utilities
source "$(dirname "$0")/utils.sh"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
TEST_RESULTS=""

setup_test_env() {
    log_message "INFO" "Setting up test environment..."
    export TEST_DIR="/tmp/eks-helm-test-$$"
    
    # Create test directory with proper error handling
    if ! mkdir -p "$TEST_DIR"; then
        log_message "FAIL" "Failed to create test directory: $TEST_DIR"
        return 1
    fi
    
    # Set up cleanup trap
    trap cleanup_test_env EXIT
    
    log_message "INFO" "Test environment ready: $TEST_DIR"
    return 0
}

cleanup_test_env() {
    if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
        log_message "INFO" "Cleaning up test environment: $TEST_DIR"
        rm -rf "$TEST_DIR" 2>/dev/null || true
    fi
}

# Helper function to safely test conditions
safe_test() {
    local test_name="$1"
    local test_function="$2"
    
    log_message "INFO" "Running test: $test_name"
    
    if $test_function; then
        log_message "PASS" "$test_name"
        return 0
    else
        log_message "FAIL" "$test_name"
        return 1
    fi
}

test_script_permissions() {
    local scripts=("scripts/entrypoint.sh" "scripts/setup-tools.sh" "scripts/health-check.sh" "scripts/cleanup.sh")
    local all_executable=true
    
    for script in "${scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            log_message "INFO" "✗ $script not found"
            all_executable=false
        elif [[ ! -x "$script" ]]; then
            log_message "INFO" "✗ $script not executable"
            all_executable=false
        else
            log_message "INFO" "✓ $script is executable"
        fi
    done
    
    return $([[ "$all_executable" == "true" ]] && echo 0 || echo 1)
}

test_required_files() {
    local files=("action.yml" "Dockerfile" "README.md" "LICENSE.md")
    local all_exist=true
    
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_message "INFO" "✗ $file not found"
            all_exist=false
        else
            log_message "INFO" "✓ $file exists"
        fi
    done
    
    return $([[ "$all_exist" == "true" ]] && echo 0 || echo 1)
}

test_dockerfile_syntax() {
    if [[ ! -f "Dockerfile" ]]; then
        log_message "INFO" "✗ Dockerfile not found"
        return 1
    fi
    
    # Basic Dockerfile syntax checks
    local has_from=false
    local has_entrypoint=false
    
    if grep -q "^FROM " Dockerfile; then
        log_message "INFO" "✓ Dockerfile has FROM instruction"
        has_from=true
    else
        log_message "INFO" "✗ Dockerfile missing FROM instruction"
    fi
    
    if grep -q "^ENTRYPOINT " Dockerfile || grep -q "^CMD " Dockerfile; then
        log_message "INFO" "✓ Dockerfile has entry point"
        has_entrypoint=true
    else
        log_message "INFO" "✗ Dockerfile missing ENTRYPOINT or CMD instruction"
    fi
    
    return $([[ "$has_from" == "true" && "$has_entrypoint" == "true" ]] && echo 0 || echo 1)
}

test_action_yml_syntax() {
    if [[ ! -f "action.yml" ]]; then
        log_message "INFO" "✗ action.yml not found"
        return 1
    fi
    
    # Check required fields
    local required_fields=("name:" "description:" "runs:")
    local all_present=true
    
    for field in "${required_fields[@]}"; do
        if grep -q "^${field}" action.yml; then
            log_message "INFO" "✓ action.yml has $field"
        else
            log_message "INFO" "✗ action.yml missing $field"
            all_present=false
        fi
    done
    
    # Check Docker configuration
    if grep -q "using: 'docker'" action.yml && grep -q "image: 'Dockerfile'" action.yml; then
        log_message "INFO" "✓ action.yml configured for Docker"
    else
        log_message "INFO" "✗ action.yml Docker configuration invalid"
        all_present=false
    fi
    
    return $([[ "$all_present" == "true" ]] && echo 0 || echo 1)
}

test_template_files() {
    local templates=("templates/config.template" "templates/private-config.template")
    local all_valid=true
    
    for template in "${templates[@]}"; do
        if [[ ! -f "$template" ]]; then
            log_message "INFO" "✗ $template not found"
            all_valid=false
            continue
        fi
        
        # Check for required template variables
        if grep -q '\${CLUSTER_NAME}' "$template" && grep -q '\${REGION_CODE}' "$template"; then
            log_message "INFO" "✓ $template has required variables"
        else
            log_message "INFO" "✗ $template missing required variables"
            all_valid=false
        fi
    done
    
    return $([[ "$all_valid" == "true" ]] && echo 0 || echo 1)
}

test_script_syntax() {
    local scripts=("scripts/entrypoint.sh" "scripts/health-check.sh" "scripts/setup-tools.sh" "scripts/cleanup.sh")
    local all_valid=true
    
    for script in "${scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            log_message "INFO" "⚠ $script not found (skipping syntax check)"
            continue
        fi
        
        # Basic bash syntax check
        if bash -n "$script" 2>/dev/null; then
            log_message "INFO" "✓ $script syntax valid"
        else
            log_message "INFO" "✗ $script syntax error"
            all_valid=false
        fi
        
        # Check for shebang
        if head -1 "$script" | grep -q "^#!/bin/bash"; then
            log_message "INFO" "✓ $script has proper shebang"
        else
            log_message "INFO" "⚠ $script missing proper shebang"
        fi
    done
    
    return $([[ "$all_valid" == "true" ]] && echo 0 || echo 1)
}

test_documentation() {
    local docs=("README.md" "CHANGELOG.md" "docs/MIGRATION.md" "docs/SECURITY.md")
    local all_present=true
    
    for doc in "${docs[@]}"; do
        if [[ ! -f "$doc" ]]; then
            log_message "INFO" "✗ $doc not found"
            all_present=false
        else
            # Check if file is not empty
            if [[ -s "$doc" ]]; then
                log_message "INFO" "✓ $doc exists and is not empty"
            else
                log_message "INFO" "✗ $doc is empty"
                all_present=false
            fi
        fi
    done
    
    return $([[ "$all_present" == "true" ]] && echo 0 || echo 1)
}

test_github_workflows() {
    local workflows=(".github/workflows/test.yaml" ".github/workflows/release.yaml" ".github/workflows/security.yaml")
    local all_valid=true
    
    for workflow in "${workflows[@]}"; do
        if [[ ! -f "$workflow" ]]; then
            log_message "INFO" "✗ $workflow not found"
            all_valid=false
            continue
        fi
        
        # Basic structure check (don't require yq)
        if grep -q "^name:" "$workflow" && grep -q "^on:" "$workflow"; then
            log_message "INFO" "✓ $workflow has basic structure"
        else
            log_message "INFO" "✗ $workflow missing required fields"
            all_valid=false
        fi
    done
    
    return $([[ "$all_valid" == "true" ]] && echo 0 || echo 1)
}

main() {
    log_message "INFO" "=== EKS Helm Client Unit Tests ===" "Starting tests"
    
    # Setup test environment
    if ! setup_test_env; then
        log_message "FAIL" "Failed to setup test environment"
        exit 1
    fi
    
    # Track results manually
    local test_results=()
    
    # Run all tests and capture results
    if safe_test "Script Permissions" test_script_permissions; then
        test_results+=("PASS")
    else
        test_results+=("FAIL")
    fi
    
    if safe_test "Required Files" test_required_files; then
        test_results+=("PASS")
    else
        test_results+=("FAIL")
    fi
    
    if safe_test "Dockerfile Syntax" test_dockerfile_syntax; then
        test_results+=("PASS")
    else
        test_results+=("FAIL")
    fi
    
    if safe_test "action.yml Syntax" test_action_yml_syntax; then
        test_results+=("PASS")
    else
        test_results+=("FAIL")
    fi
    
    if safe_test "Template Files" test_template_files; then
        test_results+=("PASS")
    else
        test_results+=("FAIL")
    fi
    
    if safe_test "Script Syntax" test_script_syntax; then
        test_results+=("PASS")
    else
        test_results+=("FAIL")
    fi
    
    if safe_test "Documentation" test_documentation; then
        test_results+=("PASS")
    else
        test_results+=("FAIL")
    fi
    
    if safe_test "GitHub Workflows" test_github_workflows; then
        test_results+=("PASS")
    else
        test_results+=("FAIL")
    fi
    
    # Count results
    local passed=0
    local failed=0
    
    for result in "${test_results[@]}"; do
        if [[ "$result" == "PASS" ]]; then
            ((passed++))
        else
            ((failed++))
        fi
    done
    
    log_message "INFO" "=== Test Results Summary ==="
    echo -e "${GREEN}Passed:${NC} $passed"
    echo -e "${RED}Failed:${NC} $failed"
    echo -e "${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
    
    if [[ $failed -gt 0 ]]; then
        log_message "FAIL" "Unit tests failed! ($failed failures)"
        exit 1
    else
        log_message "PASS" "All unit tests passed! ($passed tests)"
        exit 0
    fi
}

main