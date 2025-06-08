#!/bin/bash
# tests/unit/test-entrypoint.sh
# Unit tests for entrypoint.sh script

set -e

# Source shared testing utilities
source "$(dirname "$0")/../../.github/scripts/testing/utils.sh"

# Reset counters for this script
reset_counters

# Test configuration
readonly ENTRYPOINT_SCRIPT="scripts/entrypoint.sh"

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

test_entrypoint_exists() {
    if [[ -f "$ENTRYPOINT_SCRIPT" ]]; then
        log_info "✓ Entrypoint script exists"
        return 0
    else
        log_error "Entrypoint script not found: $ENTRYPOINT_SCRIPT"
        return 1
    fi
}

test_entrypoint_executable() {
    if [[ -x "$ENTRYPOINT_SCRIPT" ]]; then
        log_info "✓ Entrypoint script is executable"
        return 0
    else
        log_error "Entrypoint script is not executable"
        return 1
    fi
}

test_entrypoint_syntax() {
    if bash -n "$ENTRYPOINT_SCRIPT" 2>/dev/null; then
        log_info "✓ Entrypoint script syntax is valid"
        return 0
    else
        log_error "Entrypoint script has syntax errors"
        return 1
    fi
}

test_entrypoint_shebang() {
    local shebang
    shebang=$(head -1 "$ENTRYPOINT_SCRIPT")
    
    if [[ "$shebang" == "#!/bin/bash" ]]; then
        log_info "✓ Entrypoint script has correct shebang"
        return 0
    else
        log_error "Entrypoint script has incorrect shebang: $shebang"
        return 1
    fi
}

test_entrypoint_error_handling() {
    if grep -q "set -e" "$ENTRYPOINT_SCRIPT"; then
        log_info "✓ Entrypoint script uses 'set -e'"
        return 0
    else
        log_warn "Entrypoint script should use 'set -e' for error handling"
        increment_warnings
        return 0
    fi
}

test_entrypoint_functions() {
    # Check for required functions
    local required_functions=("log_info" "log_error" "log_success" "cleanup")
    local all_present=true
    
    for func in "${required_functions[@]}"; do
        if grep -q "^${func}()" "$ENTRYPOINT_SCRIPT" || grep -q "${func}() {" "$ENTRYPOINT_SCRIPT"; then
            log_info "✓ Function $func is defined"
        else
            log_warn "Function $func not found (may be defined differently)"
            increment_warnings
        fi
    done
    
    return 0
}

test_entrypoint_input_validation() {
    # Check for input parameter validation
    local required_validations=("CLUSTER_NAME" "REGION_CODE")
    local all_present=true
    
    for param in "${required_validations[@]}"; do
        if grep -q "$param" "$ENTRYPOINT_SCRIPT"; then
            log_info "✓ Script references $param"
        else
            log_error "Script missing reference to $param"
            all_present=false
        fi
    done
    
    return $([[ "$all_present" == "true" ]] && echo 0 || echo 1)
}

test_entrypoint_aws_tools() {
    # Check for AWS tool usage
    local aws_tools=("aws" "kubectl" "helm")
    
    for tool in "${aws_tools[@]}"; do
        if grep -q "$tool" "$ENTRYPOINT_SCRIPT"; then
            log_info "✓ Script uses $tool"
        else
            log_warn "Script may not use $tool"
            increment_warnings
        fi
    done
    
    return 0
}

test_entrypoint_cleanup_trap() {
    if grep -q "trap.*cleanup" "$ENTRYPOINT_SCRIPT"; then
        log_info "✓ Script sets up cleanup trap"
        return 0
    else
        log_warn "Script should set up cleanup trap"
        increment_warnings
        return 0
    fi
}

test_entrypoint_debug_mode() {
    if grep -q "INPUT_DEBUG" "$ENTRYPOINT_SCRIPT"; then
        log_info "✓ Script supports debug mode"
        return 0
    else
        log_warn "Script should support debug mode"
        increment_warnings
        return 0
    fi
}

main() {
    log_info "=== Entrypoint Script Unit Tests ==="
    
    # Run all tests
    run_test "Script Exists" test_entrypoint_exists
    run_test "Script Executable" test_entrypoint_executable
    run_test "Script Syntax" test_entrypoint_syntax
    run_test "Script Shebang" test_entrypoint_shebang
    run_test "Error Handling" test_entrypoint_error_handling
    run_test "Required Functions" test_entrypoint_functions
    run_test "Input Validation" test_entrypoint_input_validation
    run_test "AWS Tools Usage" test_entrypoint_aws_tools
    run_test "Cleanup Trap" test_entrypoint_cleanup_trap
    run_test "Debug Mode Support" test_entrypoint_debug_mode
    
    # Exit with summary
    exit_with_summary "Entrypoint Tests"
}

main