#!/bin/bash
# tests/unit/test-health-check.sh
# Unit tests for health-check.sh script

set -e

# Source shared testing utilities
source "$(dirname "$0")/../../.github/scripts/testing/utils.sh"

# Reset counters for this script
reset_counters

# Test configuration
readonly HEALTH_CHECK_SCRIPT="scripts/health-check.sh"

# Helper function to run tests
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    log_info "Running test: $test_name"
    
    if $test_function; then
        log_test_result "PASS" "$test_name"
        return 0
    else
        log_test_result "FAIL" "$test_name"
        return 1
    fi
}

test_health_check_exists() {
    if [[ -f "$HEALTH_CHECK_SCRIPT" ]]; then
        log_info "✓ Health check script exists"
        return 0
    else
        log_error "Health check script not found: $HEALTH_CHECK_SCRIPT"
        return 1
    fi
}

test_health_check_executable() {
    if [[ -x "$HEALTH_CHECK_SCRIPT" ]]; then
        log_info "✓ Health check script is executable"
        return 0
    else
        log_error "Health check script is not executable"
        return 1
    fi
}

test_health_check_syntax() {
    if bash -n "$HEALTH_CHECK_SCRIPT" 2>/dev/null; then
        log_info "✓ Health check script syntax is valid"
        return 0
    else
        log_error "Health check script has syntax errors"
        return 1
    fi
}

test_health_check_shebang() {
    local shebang
    shebang=$(head -1 "$HEALTH_CHECK_SCRIPT")
    
    if [[ "$shebang" == "#!/bin/bash" ]]; then
        log_info "✓ Health check script has correct shebang"
        return 0
    else
        log_error "Health check script has incorrect shebang: $shebang"
        return 1
    fi
}

test_health_check_exit_codes() {
    # Check for proper exit codes
    if grep -q "HEALTH_OK" "$HEALTH_CHECK_SCRIPT" && grep -q "HEALTH_ERROR" "$HEALTH_CHECK_SCRIPT"; then
        log_info "✓ Health check script defines proper exit codes"
        return 0
    else
        log_error "Health check script missing proper exit codes"
        return 1
    fi
}

test_health_check_functions() {
    # Check for required health check functions
    local health_functions=("check_command" "check_filesystem" "check_system_resources")
    local functions_found=0
    
    for func in "${health_functions[@]}"; do
        if grep -q "^${func}()" "$HEALTH_CHECK_SCRIPT" || grep -q "${func}() {" "$HEALTH_CHECK_SCRIPT"; then
            log_info "✓ Function $func is defined"
            ((functions_found++))
        else
            log_warn "Function $func not found"
            increment_warnings
        fi
    done
    
    if [[ $functions_found -gt 0 ]]; then
        return 0
    else
        return 1
    fi
}

test_health_check_tool_validation() {
    # Check for tool validation
    local tools=("kubectl" "helm" "aws")
    
    for tool in "${tools[@]}"; do
        if grep -q "$tool" "$HEALTH_CHECK_SCRIPT"; then
            log_info "✓ Health check validates $tool"
        else
            log_warn "Health check should validate $tool"
            increment_warnings
        fi
    done
    
    return 0
}

test_health_check_timeout() {
    if grep -q "timeout" "$HEALTH_CHECK_SCRIPT" || grep -q "TIMEOUT" "$HEALTH_CHECK_SCRIPT"; then
        log_info "✓ Health check implements timeout handling"
        return 0
    else
        log_warn "Health check should implement timeout handling"
        increment_warnings
        return 0
    fi
}

test_health_check_logging() {
    # Check for logging functions
    if grep -q "log_health" "$HEALTH_CHECK_SCRIPT" || grep -q "echo.*\[HEALTH\]" "$HEALTH_CHECK_SCRIPT"; then
        log_info "✓ Health check implements logging"
        return 0
    else
        log_warn "Health check should implement proper logging"
        increment_warnings
        return 0
    fi
}

test_health_check_quick_mode() {
    if grep -q "quick" "$HEALTH_CHECK_SCRIPT" || grep -q "--quick" "$HEALTH_CHECK_SCRIPT"; then
        log_info "✓ Health check supports quick mode"
        return 0
    else
        log_warn "Health check should support quick mode for Docker healthcheck"
        increment_warnings
        return 0
    fi
}

main() {
    log_info "=== Health Check Script Unit Tests ==="
    
    # Run all tests
    run_test "Script Exists" test_health_check_exists
    run_test "Script Executable" test_health_check_executable
    run_test "Script Syntax" test_health_check_syntax
    run_test "Script Shebang" test_health_check_shebang
    run_test "Exit Codes" test_health_check_exit_codes
    run_test "Health Check Functions" test_health_check_functions
    run_test "Tool Validation" test_health_check_tool_validation
    run_test "Timeout Handling" test_health_check_timeout
    run_test "Logging Implementation" test_health_check_logging
    run_test "Quick Mode Support" test_health_check_quick_mode
    
    # Exit with summary
    exit_with_summary "Health Check Tests"
}

main