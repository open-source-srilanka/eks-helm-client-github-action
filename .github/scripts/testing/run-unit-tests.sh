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
    mkdir -p "$TEST_DIR"
    trap 'rm -rf "$TEST_DIR"' EXIT
}

test_script_permissions() {
    local test_name="Script Permissions"
    local scripts=("scripts/entrypoint.sh" "scripts/setup-tools.sh")
    local all_executable=true
    for script in "${scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            log_message "FAIL" "$test_name - $script" "File not found"
            all_executable=false
        elif [[ ! -x "$script" ]]; then
            log_message "FAIL" "$test_name - $script" "Not executable"
            all_executable=false
        fi
    done
    if [[ "$all_executable" == "true" ]]; then
        log_message "PASS" "$test_name"
    fi
}

test_required_files() {
    local test_name="Required Files"
    local files=("action.yml" "Dockerfile" "README.md")
    local all_exist=true
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_message "FAIL" "$test_name - $file" "File not found"
            all_exist=false
        fi
    done
    if [[ "$all_exist" == "true" ]]; then
        log_message "PASS" "$test_name"
    fi
}

main() {
    log_message "INFO" "=== EKS Helm Client Unit Tests ===" "Starting tests"
    setup_test_env
    
    test_script_permissions
    test_required_files

    log_message "INFO" "=== Test Results Summary ==="
    echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
    echo -e "${RED}Failed:${NC} $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        log_message "FAIL" "Unit tests failed!"
        exit 1
    else
        log_message "PASS" "All unit tests passed!"
    fi
}

main