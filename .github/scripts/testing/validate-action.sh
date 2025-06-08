#!/bin/bash
# .github/scripts/testing/validate-action.sh

set -e

# Source shared testing utilities
source "$(dirname "$0")/utils.sh"

# Validation counters
CHECKS_PASSED=0
CHECKS_FAILED=0
WARNINGS=0
VALIDATION_RESULTS=""

validate_action_yml() {
    log_message "INFO" "Validating action.yml structure..."
    if [[ ! -f "action.yml" ]]; then
        log_message "FAIL" "action.yml exists" "File not found"
        return 1
    fi
    log_message "PASS" "action.yml exists"

    if grep -q "^name:" action.yml && [[ -n "$(grep "^name:" action.yml | cut -d':' -f2-)" ]]; then
        log_message "PASS" "action.yml has 'name'"
    else
        log_message "FAIL" "action.yml has 'name'" "Field missing or empty"
    fi

    if grep -q "^description:" action.yml && [[ -n "$(grep "^description:" action.yml | cut -d':' -f2-)" ]]; then
        log_message "PASS" "action.yml has 'description'"
    else
        log_message "FAIL" "action.yml has 'description'" "Field missing or empty"
    fi
    
    if grep -q "using: 'docker'" action.yml && grep -q "image: 'Dockerfile'" action.yml; then
        log_message "PASS" "Action uses Docker correctly"
    else
        log_message "FAIL" "Action uses Docker" "runs.using must be 'docker' and image must be 'Dockerfile'"
    fi
}

validate_documentation() {
    log_message "INFO" "Validating documentation..."
    if [[ -f "README.md" ]]; then
        log_message "PASS" "README.md exists"
    else
        log_message "FAIL" "README.md exists" "Required for marketplace"
    fi

    if [[ -f "LICENSE" ]] || [[ -f "LICENSE.md" ]]; then
        log_message "PASS" "LICENSE file exists"
    else
        log_message "FAIL" "LICENSE file exists" "Required for marketplace"
    fi
}

main() {
    log_message "INFO" "=== GitHub Action Validation ===" "Starting validation"
    
    validate_action_yml
    validate_documentation

    log_message "INFO" "=== Validation Summary ==="
    echo -e "${GREEN}Passed:${NC} $CHECKS_PASSED"
    echo -e "${RED}Failed:${NC} $CHECKS_FAILED"
    echo -e "${YELLOW}Warnings:${NC} $WARNINGS"

    if [[ $CHECKS_FAILED -gt 0 ]]; then
        log_message "FAIL" "Validation failed! Please fix the issues above."
        exit 1
    else
        if [[ $WARNINGS -gt 0 ]]; then
            log_message "WARN" "Validation passed with warnings."
        else
            log_message "PASS" "Validation passed!"
        fi
    fi
}

main