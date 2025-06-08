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

test_script_permissions() {
    local test_name="Script Permissions"
    local scripts=("scripts/entrypoint.sh" "scripts/setup-tools.sh" "scripts/health-check.sh" "scripts/cleanup.sh")
    local all_executable=true
    
    for script in "${scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            log_message "FAIL" "$test_name - $script" "File not found"
            all_executable=false
        elif [[ ! -x "$script" ]]; then
            log_message "FAIL" "$test_name - $script" "Not executable"
            all_executable=false
        else
            log_message "INFO" "✓ $script is executable"
        fi
    done
    
    if [[ "$all_executable" == "true" ]]; then
        log_message "PASS" "$test_name"
    fi
}

test_required_files() {
    local test_name="Required Files"
    local files=("action.yml" "Dockerfile" "README.md" "LICENSE.md")
    local all_exist=true
    
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_message "FAIL" "$test_name - $file" "File not found"
            all_exist=false
        else
            log_message "INFO" "✓ $file exists"
        fi
    done
    
    if [[ "$all_exist" == "true" ]]; then
        log_message "PASS" "$test_name"
    fi
}

test_dockerfile_syntax() {
    local test_name="Dockerfile Syntax"
    
    if [[ ! -f "Dockerfile" ]]; then
        log_message "FAIL" "$test_name" "Dockerfile not found"
        return
    fi
    
    # Basic Dockerfile syntax checks
    if grep -q "^FROM " Dockerfile; then
        log_message "INFO" "✓ Dockerfile has FROM instruction"
    else
        log_message "FAIL" "$test_name" "Missing FROM instruction"
        return
    fi
    
    if grep -q "^ENTRYPOINT " Dockerfile || grep -q "^CMD " Dockerfile; then
        log_message "INFO" "✓ Dockerfile has entry point"
    else
        log_message "FAIL" "$test_name" "Missing ENTRYPOINT or CMD instruction"
        return
    fi
    
    log_message "PASS" "$test_name"
}

test_action_yml_syntax() {
    local test_name="action.yml Syntax"
    
    if [[ ! -f "action.yml" ]]; then
        log_message "FAIL" "$test_name" "action.yml not found"
        return
    fi
    
    # Check required fields
    local required_fields=("name:" "description:" "runs:" "inputs:")
    local all_present=true
    
    for field in "${required_fields[@]}"; do
        if grep -q "^${field}" action.yml; then
            log_message "INFO" "✓ action.yml has $field"
        else
            log_message "FAIL" "$test_name" "Missing required field: $field"
            all_present=false
        fi
    done
    
    # Check Docker configuration
    if grep -q "using: 'docker'" action.yml && grep -q "image: 'Dockerfile'" action.yml; then
        log_message "INFO" "✓ action.yml configured for Docker"
    else
        log_message "FAIL" "$test_name" "Docker configuration invalid"
        all_present=false
    fi
    
    if [[ "$all_present" == "true" ]]; then
        log_message "PASS" "$test_name"
    fi
}

test_template_files() {
    local test_name="Template Files"
    local templates=("templates/config.template" "templates/private-config.template")
    local all_valid=true
    
    for template in "${templates[@]}"; do
        if [[ ! -f "$template" ]]; then
            log_message "FAIL" "$test_name - $template" "Template not found"
            all_valid=false
            continue
        fi
        
        # Check for required template variables
        if grep -q '\${CLUSTER_NAME}' "$template" && grep -q '\${REGION_CODE}' "$template"; then
            log_message "INFO" "✓ $template has required variables"
        else
            log_message "FAIL" "$test_name - $template" "Missing required template variables"
            all_valid=false
        fi
    done
    
    if [[ "$all_valid" == "true" ]]; then
        log_message "PASS" "$test_name"
    fi
}

test_script_syntax() {
    local test_name="Script Syntax"
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
            log_message "FAIL" "$test_name - $script" "Syntax error detected"
            all_valid=false
        fi
        
        # Check for shebang
        if head -1 "$script" | grep -q "^#!/bin/bash"; then
            log_message "INFO" "✓ $script has proper shebang"
        else
            log_message "WARN" "$test_name - $script" "Missing or invalid shebang"
        fi
    done
    
    if [[ "$all_valid" == "true" ]]; then
        log_message "PASS" "$test_name"
    fi
}

test_documentation() {
    local test_name="Documentation"
    local docs=("README.md" "CHANGELOG.md" "docs/MIGRATION.md" "docs/SECURITY.md")
    local all_present=true
    
    for doc in "${docs[@]}"; do
        if [[ ! -f "$doc" ]]; then
            log_message "FAIL" "$test_name - $doc" "Documentation file not found"
            all_present=false
        else
            # Check if file is not empty
            if [[ -s "$doc" ]]; then
                log_message "INFO" "✓ $doc exists and is not empty"
            else
                log_message "FAIL" "$test_name - $doc" "Documentation file is empty"
                all_present=false
            fi
        fi
    done
    
    if [[ "$all_present" == "true" ]]; then
        log_message "PASS" "$test_name"
    fi
}

test_github_workflows() {
    local test_name="GitHub Workflows"
    local workflows=(".github/workflows/test.yaml" ".github/workflows/release.yaml" ".github/workflows/security.yaml")
    local all_valid=true
    
    for workflow in "${workflows[@]}"; do
        if [[ ! -f "$workflow" ]]; then
            log_message "FAIL" "$test_name - $workflow" "Workflow file not found"
            all_valid=false
            continue
        fi
        
        # Basic YAML syntax check (if yq is available)
        if command -v yq >/dev/null 2>&1; then
            if yq eval . "$workflow" >/dev/null 2>&1; then
                log_message "INFO" "✓ $workflow syntax valid"
            else
                log_message "FAIL" "$test_name - $workflow" "YAML syntax error"
                all_valid=false
            fi
        else
            # Basic structure check
            if grep -q "^name:" "$workflow" && grep -q "^on:" "$workflow"; then
                log_message "INFO" "✓ $workflow has basic structure"
            else
                log_message "FAIL" "$test_name - $workflow" "Missing required workflow fields"
                all_valid=false
            fi
        fi
    done
    
    if [[ "$all_valid" == "true" ]]; then
        log_message "PASS" "$test_name"
    fi
}

main() {
    log_message "INFO" "=== EKS Helm Client Unit Tests ===" "Starting tests"
    
    # Setup test environment
    if ! setup_test_env; then
        log_message "FAIL" "Failed to setup test environment"
        exit 1
    fi
    
    # Run all tests
    test_script_permissions
    test_required_files
    test_dockerfile_syntax
    test_action_yml_syntax
    test_template_files
    test_script_syntax
    test_documentation
    test_github_workflows

    log_message "INFO" "=== Test Results Summary ==="
    echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
    echo -e "${RED}Failed:${NC} $TESTS_FAILED"
    echo -e "${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        log_message "FAIL" "Unit tests failed!"
        exit 1
    else
        log_message "PASS" "All unit tests passed!"
    fi
}

main