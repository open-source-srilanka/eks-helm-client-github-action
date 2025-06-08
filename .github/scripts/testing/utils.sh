#!/bin/bash
# .github/scripts/testing/utils.sh
# Shared utilities for testing scripts

# Prevent multiple sourcing issues
if [[ "${UTILS_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
export UTILS_SH_LOADED=true

# Color codes for output - only define if not already defined
if [[ -z "${RED:-}" ]]; then
    if [[ -t 1 ]]; then
        readonly RED='\033[0;31m'
        readonly GREEN='\033[0;32m'
        readonly YELLOW='\033[1;33m'
        readonly BLUE='\033[0;34m'
        readonly NC='\033[0m'
    else
        readonly RED=''
        readonly GREEN=''
        readonly YELLOW=''
        readonly BLUE=''
        readonly NC=''
    fi
fi

# Global test counters - Initialize only if not already set
declare -g TESTS_PASSED=${TESTS_PASSED:-0}
declare -g TESTS_FAILED=${TESTS_FAILED:-0}
declare -g TESTS_SKIPPED=${TESTS_SKIPPED:-0}
declare -g WARNINGS=${WARNINGS:-0}
declare -g CHECKS_PASSED=${CHECKS_PASSED:-0}
declare -g CHECKS_FAILED=${CHECKS_FAILED:-0}

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
            ((WARNINGS++))
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
    if [[ $TESTS_FAILED -eq 0 ]]; then
        return 0
    else
        return 1
    fi
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

# Helper function for running tests safely
run_test_safe() {
    local test_name="$1"
    local test_function="$2"
    local continue_on_failure="${3:-true}"
    
    log_info "Running test: $test_name"
    
    # Temporarily disable exit on error if needed
    local old_set_e=""
    if [[ "$continue_on_failure" == "true" ]]; then
        if [[ $- =~ e ]]; then
            old_set_e="true"
            set +e
        fi
    fi
    
    # Run the test
    if $test_function; then
        log_test_result "PASS" "$test_name"
        local result=0
    else
        log_test_result "FAIL" "$test_name"
        local result=1
    fi
    
    # Restore set -e if it was enabled
    if [[ "$old_set_e" == "true" ]]; then
        set -e
    fi
    
    return $result
}

# Function to validate that required commands exist
check_dependencies() {
    local dependencies=("$@")
    local missing_deps=()
    
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        return 1
    fi
    
    return 0
}

# Function to create temporary directory safely
create_temp_dir() {
    local prefix="${1:-test}"
    local temp_dir
    
    temp_dir=$(mktemp -d "/tmp/${prefix}-$$-XXXXXX")
    if [[ ! -d "$temp_dir" ]]; then
        log_error "Failed to create temporary directory"
        return 1
    fi
    
    echo "$temp_dir"
    return 0
}

# Function to safely remove directory
safe_remove_dir() {
    local dir="$1"
    local description="${2:-directory}"
    
    if [[ -n "$dir" && -d "$dir" ]]; then
        if rm -rf "$dir" 2>/dev/null; then
            log_info "Removed $description: $dir"
        else
            log_warn "Failed to remove $description: $dir"
        fi
    fi
}

# Function to check if script is being run in CI
is_ci() {
    [[ "${CI:-}" == "true" ]] || [[ "${GITHUB_ACTIONS:-}" == "true" ]] || [[ -n "${JENKINS_URL:-}" ]]
}

# Function to check if output supports colors
supports_colors() {
    [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]] && [[ "${NO_COLOR:-}" != "1" ]]
}

# Function to set debug mode
set_debug_mode() {
    local debug="${1:-false}"
    
    if [[ "$debug" == "true" ]]; then
        set -x
        log_info "Debug mode enabled"
    else
        set +x
    fi
}

# Initialization function
init_utils() {
    local debug="${1:-false}"
    
    # Set debug mode if requested
    set_debug_mode "$debug"
    
    # Reset counters
    reset_counters
    
    log_info "Testing utilities initialized"
}

# Export functions for use in other scripts
export -f log_info log_warn log_error log_success
export -f log_test_result log_message
export -f increment_passed increment_failed increment_skipped increment_warnings
export -f get_test_summary tests_passed reset_counters
export -f print_test_summary exit_with_summary
export -f run_test_safe check_dependencies
export -f create_temp_dir safe_remove_dir
export -f is_ci supports_colors set_debug_mode init_utils