#!/bin/bash
# .github/scripts/testing/utils.sh
# Shared utilities for testing scripts

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Global test counters - Initialize only if not already set
TESTS_PASSED=${TESTS_PASSED:-0}
TESTS_FAILED=${TESTS_FAILED:-0}
TESTS_SKIPPED=${TESTS_SKIPPED:-0}
WARNINGS=${WARNINGS:-0}
CHECKS_PASSED=${CHECKS_PASSED:-0}
CHECKS_FAILED=${CHECKS_FAILED:-0}

# Function to log test results WITHOUT affecting counters
# This version is safe to use for informational messages
log_info() {
    local message="$1"
    echo -e "${BLUE}[INFO]${NC} $message" >&2
}

log_warn() {
    local message="$1"
    echo -e "${YELLOW}[WARN]${NC} $message" >&2
}

log_error() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} $message" >&2
}

log_success() {
    local message="$1"
    echo -e "${GREEN}[SUCCESS]${NC} $message" >&2
}

# Function to log test results WITH counter updates
# Use this only when you want to affect global counters
log_test_result() {
    local status=$1
    local name=$2
    local message=${3:-""}

    case $status in
        "PASS")
            echo -e "${GREEN}✓${NC} $name" >&2
            ((TESTS_PASSED++))
            ((CHECKS_PASSED++))
            ;;
        "FAIL")
            echo -e "${RED}✗${NC} $name: $message" >&2
            ((TESTS_FAILED++))
            ((CHECKS_FAILED++))
            ;;
        "SKIP")
            echo -e "${YELLOW}○${NC} $name: $message" >&2
            ((TESTS_SKIPPED++))
            ;;
        "WARN")
            echo -e "${YELLOW}⚠${NC} $name: $message" >&2
            ((WARNINGS++))
            ;;
    esac
}

# Legacy function for backward compatibility - but safer
# This is the old log_message function but modified to be safer
log_message() {
    local status=$1
    local name=$2
    local message=${3:-""}

    case $status in
        "INFO")
            log_info "$name: $message"
            ;;
        "WARN")
            log_warn "$name: $message"
            ;;
        "PASS")
            echo -e "${GREEN}✓${NC} $name" >&2
            # Don't auto-increment for PASS - let calling script handle it
            ;;
        "FAIL")
            echo -e "${RED}✗${NC} $name: $message" >&2
            # Don't auto-increment for FAIL - let calling script handle it
            ;;
        "SKIP")
            echo -e "${YELLOW}○${NC} $name: $message" >&2
            ;;
    esac
}

# Function to safely increment counters
increment_passed() {
    ((TESTS_PASSED++))
    ((CHECKS_PASSED++))
}

increment_failed() {
    ((TESTS_FAILED++))
    ((CHECKS_FAILED++))
}

increment_skipped() {
    ((TESTS_SKIPPED++))
}

increment_warnings() {
    ((WARNINGS++))
}

# Function to get test summary
get_test_summary() {
    echo "Passed: $TESTS_PASSED, Failed: $TESTS_FAILED, Skipped: $TESTS_SKIPPED, Warnings: $WARNINGS"
}

# Function to check if tests passed
tests_passed() {
    return $([[ $TESTS_FAILED -eq 0 ]] && echo 0 || echo 1)
}

# Function to reset counters
reset_counters() {
    TESTS_PASSED=0
    TESTS_FAILED=0
    TESTS_SKIPPED=0
    WARNINGS=0
    CHECKS_PASSED=0
    CHECKS_FAILED=0
}

# Function to print final summary
print_test_summary() {
    local script_name="${1:-Test}"
    
    echo -e "\n${BLUE}=== $script_name Results Summary ===${NC}" >&2
    echo -e "${GREEN}Passed:${NC} $TESTS_PASSED" >&2
    echo -e "${RED}Failed:${NC} $TESTS_FAILED" >&2
    echo -e "${YELLOW}Skipped:${NC} $TESTS_SKIPPED" >&2
    
    if [[ $WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}Warnings:${NC} $WARNINGS" >&2
    fi
}

# Function to exit with appropriate code
exit_with_summary() {
    local script_name="${1:-Test}"
    
    print_test_summary "$script_name"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}[FAIL]${NC} $script_name failed! ($TESTS_FAILED failures)" >&2
        exit 1
    else
        if [[ $WARNINGS -gt 0 ]]; then
            echo -e "${YELLOW}[PASS]${NC} $script_name passed with warnings" >&2
        else
            echo -e "${GREEN}[PASS]${NC} All $script_name passed! ($TESTS_PASSED tests)" >&2
        fi
        exit 0
    fi
}