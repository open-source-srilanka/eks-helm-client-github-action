#!/bin/bash
# tests/unit/test-templates.sh
# Unit tests for configuration template files

set -e

# Source shared testing utilities
source "$(dirname "$0")/../../.github/scripts/testing/utils.sh"

# Reset counters for this script
reset_counters

# Test configuration
readonly CONFIG_TEMPLATE="templates/config.template"
readonly PRIVATE_CONFIG_TEMPLATE="templates/private-config.template"
readonly HELM_VALUES_TEMPLATE="templates/helm-values.template"

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

test_template_files_exist() {
    local all_exist=true
    
    if [[ -f "$CONFIG_TEMPLATE" ]]; then
        log_info "✓ Standard config template exists"
    else
        log_error "Standard config template missing: $CONFIG_TEMPLATE"
        all_exist=false
    fi
    
    if [[ -f "$PRIVATE_CONFIG_TEMPLATE" ]]; then
        log_info "✓ Private config template exists"
    else
        log_error "Private config template missing: $PRIVATE_CONFIG_TEMPLATE"
        all_exist=false
    fi
    
    if [[ -f "$HELM_VALUES_TEMPLATE" ]]; then
        log_info "✓ Helm values template exists"
    else
        log_warn "Helm values template missing: $HELM_VALUES_TEMPLATE"
        increment_warnings
    fi
    
    return $([[ "$all_exist" == "true" ]] && echo 0 || echo 1)
}

test_config_template_structure() {
    if [[ ! -f "$CONFIG_TEMPLATE" ]]; then
        return 1
    fi
    
    # Check for required YAML structure
    if grep -q "apiVersion: v1" "$CONFIG_TEMPLATE" && grep -q "kind: Config" "$CONFIG_TEMPLATE"; then
        log_info "✓ Config template has proper YAML structure"
    else
        log_error "Config template missing proper YAML structure"
        return 1
    fi
    
    # Check for required sections
    local required_sections=("clusters:" "contexts:" "users:")
    local all_present=true
    
    for section in "${required_sections[@]}"; do
        if grep -q "$section" "$CONFIG_TEMPLATE"; then
            log_info "✓ Config template has $section section"
        else
            log_error "Config template missing $section section"
            all_present=false
        fi
    done
    
    return $([[ "$all_present" == "true" ]] && echo 0 || echo 1)
}

test_config_template_variables() {
    if [[ ! -f "$CONFIG_TEMPLATE" ]]; then
        return 1
    fi
    
    # Check for required template variables
    local required_vars=(
        "\${CLUSTER_NAME}"
        "\${REGION_CODE}"
        "\${ENDPOINT_URL}"
        "\${CA_CERT}"
    )
    local all_present=true
    
    for var in "${required_vars[@]}"; do
        if grep -q "$var" "$CONFIG_TEMPLATE"; then
            log_info "✓ Config template contains $var"
        else
            log_error "Config template missing $var"
            all_present=false
        fi
    done
    
    # Check for AWS authentication configuration
    if grep -q "aws.*eks.*get-token" "$CONFIG_TEMPLATE"; then
        log_info "✓ Config template has AWS EKS authentication"
    else
        log_error "Config template missing AWS EKS authentication"
        all_present=false
    fi
    
    return $([[ "$all_present" == "true" ]] && echo 0 || echo 1)
}

test_private_config_template_structure() {
    if [[ ! -f "$PRIVATE_CONFIG_TEMPLATE" ]]; then
        return 1
    fi
    
    # Check for private cluster specific features
    local private_features=(
        "private-cluster"
        "vpc"
        "VPC_ENDPOINT"
        "PRIVATE_"
    )
    local features_found=0
    
    for feature in "${private_features[@]}"; do
        if grep -qi "$feature" "$PRIVATE_CONFIG_TEMPLATE"; then
            log_info "✓ Private config template has $feature configuration"
            ((features_found++))
        fi
    done
    
    if [[ $features_found -gt 0 ]]; then
        log_info "✓ Private config template has private cluster features"
        return 0
    else
        log_error "Private config template missing private cluster features"
        return 1
    fi
}

test_private_config_template_variables() {
    if [[ ! -f "$PRIVATE_CONFIG_TEMPLATE" ]]; then
        return 1
    fi
    
    # Check for private cluster specific variables
    local private_vars=(
        "\${VPC_ID}"
        "\${PRIVATE_SUBNETS}"
        "\${SECURITY_GROUPS}"
        "\${VPC_ENDPOINT"
    )
    local vars_found=0
    
    for var in "${private_vars[@]}"; do
        if grep -q "$var" "$PRIVATE_CONFIG_TEMPLATE"; then
            log_info "✓ Private config template contains $var"
            ((vars_found++))
        fi
    done
    
    if [[ $vars_found -gt 0 ]]; then
        return 0
    else
        log_warn "Private config template should contain more private-specific variables"
        increment_warnings
        return 0
    fi
}

test_helm_values_template_structure() {
    if [[ ! -f "$HELM_VALUES_TEMPLATE" ]]; then
        log_warn "Helm values template not found, skipping structure test"
        increment_warnings
        return 0
    fi
    
    # Check for common Helm values sections
    local helm_sections=(
        "global:"
        "app:"
        "deployment:"
        "service:"
        "image:"
    )
    local sections_found=0
    
    for section in "${helm_sections[@]}"; do
        if grep -q "$section" "$HELM_VALUES_TEMPLATE"; then
            log_info "✓ Helm values template has $section section"
            ((sections_found++))
        fi
    done
    
    if [[ $sections_found -gt 2 ]]; then
        log_info "✓ Helm values template has good structure"
        return 0
    else
        log_warn "Helm values template could have more comprehensive structure"
        increment_warnings
        return 0
    fi
}

test_template_substitution() {
    if [[ ! -f "$CONFIG_TEMPLATE" ]]; then
        return 1
    fi
    
    # Test that template variables are properly formatted for envsubst
    local test_vars=(
        "CLUSTER_NAME"
        "REGION_CODE"
        "ENDPOINT_URL"
        "CA_CERT"
    )
    
    for var in "${test_vars[@]}"; do
        # Check that variables are in ${VAR} format, not $VAR
        if grep -q "\${${var}}" "$CONFIG_TEMPLATE"; then
            log_info "✓ Variable $var properly formatted for substitution"
        elif grep -q "\${var}" "$CONFIG_TEMPLATE"; then
            log_warn "Variable $var should use \${} format for envsubst"
            increment_warnings
        fi
    done
    
    return 0
}

test_template_yaml_validity() {
    # Test that templates would produce valid YAML after substitution
    local temp_dir="/tmp/template-test-$"
    mkdir -p "$temp_dir"
    
    # Test config template with dummy values
    if [[ -f "$CONFIG_TEMPLATE" ]]; then
        local test_config="$temp_dir/test-config.yaml"
        
        # Set test environment variables
        export CLUSTER_NAME="test-cluster"
        export REGION_CODE="us-west-2"
        export ENDPOINT_URL="https://test.eks.amazonaws.com"
        export CA_CERT="LS0tLS1CRUdJTi0tLS0t"
        export AWS_ACCOUNT_ID="123456789012"
        export USER_NAME="test-user"
        export CONTEXT_NAME="test-context"
        
        # Substitute variables
        if envsubst < "$CONFIG_TEMPLATE" > "$test_config" 2>/dev/null; then
            log_info "✓ Config template substitution successful"
            
            # Basic YAML validation (check for proper structure)
            if grep -q "apiVersion: v1" "$test_config" && grep -q "kind: Config" "$test_config"; then
                log_info "✓ Generated config has valid YAML structure"
            else
                log_error "Generated config has invalid YAML structure"
                rm -rf "$temp_dir"
                return 1
            fi
        else
            log_error "Config template substitution failed"
            rm -rf "$temp_dir"
            return 1
        fi
    fi
    
    # Test private config template
    if [[ -f "$PRIVATE_CONFIG_TEMPLATE" ]]; then
        local test_private_config="$temp_dir/test-private-config.yaml"
        
        # Additional private cluster variables
        export VPC_ID="vpc-12345678"
        export PRIVATE_SUBNETS="subnet-12345,subnet-67890"
        export SECURITY_GROUPS="sg-12345678"
        
        if envsubst < "$PRIVATE_CONFIG_TEMPLATE" > "$test_private_config" 2>/dev/null; then
            log_info "✓ Private config template substitution successful"
        else
            log_error "Private config template substitution failed"
            rm -rf "$temp_dir"
            return 1
        fi
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    unset CLUSTER_NAME REGION_CODE ENDPOINT_URL CA_CERT AWS_ACCOUNT_ID USER_NAME CONTEXT_NAME
    unset VPC_ID PRIVATE_SUBNETS SECURITY_GROUPS
    
    return 0
}

test_template_comments() {
    # Check that templates have helpful comments
    local templates=("$CONFIG_TEMPLATE" "$PRIVATE_CONFIG_TEMPLATE")
    
    for template in "${templates[@]}"; do
        if [[ ! -f "$template" ]]; then
            continue
        fi
        
        local comment_lines
        comment_lines=$(grep -c "^#" "$template" 2>/dev/null || echo "0")
        
        if [[ $comment_lines -gt 5 ]]; then
            log_info "✓ Template $(basename "$template") has good documentation ($comment_lines comment lines)"
        else
            log_warn "Template $(basename "$template") could use more comments ($comment_lines comment lines)"
            increment_warnings
        fi
    done
    
    return 0
}

test_template_security() {
    # Check that templates don't contain hardcoded secrets
    local templates=("$CONFIG_TEMPLATE" "$PRIVATE_CONFIG_TEMPLATE" "$HELM_VALUES_TEMPLATE")
    local security_issues=0
    
    for template in "${templates[@]}"; do
        if [[ ! -f "$template" ]]; then
            continue
        fi
        
        # Check for potential hardcoded secrets
        local secret_patterns=(
            "password.*="
            "secret.*="
            "key.*=.*[A-Za-z0-9]{20,}"
            "token.*="
            "AKIA[0-9A-Z]{16}"  # AWS Access Key pattern
        )
        
        for pattern in "${secret_patterns[@]}"; do
            if grep -qi "$pattern" "$template"; then
                log_error "Template $(basename "$template") may contain hardcoded secrets: $pattern"
                security_issues=1
            fi
        done
        
        # Check for proper variable substitution
        if grep -q "\${.*PASSWORD}" "$template" || grep -q "\${.*SECRET}" "$template"; then
            log_info "✓ Template $(basename "$template") uses variable substitution for secrets"
        fi
    done
    
    if [[ $security_issues -eq 0 ]]; then
        log_info "✓ No hardcoded secrets found in templates"
    fi
    
    return $security_issues
}

test_template_private_registry_support() {
    # Check if templates support private registry configurations
    local templates=("$CONFIG_TEMPLATE" "$PRIVATE_CONFIG_TEMPLATE" "$HELM_VALUES_TEMPLATE")
    local registry_support=0
    
    for template in "${templates[@]}"; do
        if [[ ! -f "$template" ]]; then
            continue
        fi
        
        local registry_features=(
            "registry"
            "REGISTRY"
            "HELM_REGISTRY"
            "private-registry"
            "harbor"
            "nexus"
            "artifactory"
        )
        
        for feature in "${registry_features[@]}"; do
            if grep -qi "$feature" "$template"; then
                log_info "✓ Template $(basename "$template") supports private registries"
                registry_support=1
                break
            fi
        done
    done
    
    if [[ $registry_support -eq 0 ]]; then
        log_warn "Templates could include more private registry support"
        increment_warnings
    fi
    
    return 0
}

main() {
    log_info "=== Configuration Template Unit Tests ==="
    
    # Run all tests
    run_test "Template Files Exist" test_template_files_exist
    run_test "Config Template Structure" test_config_template_structure
    run_test "Config Template Variables" test_config_template_variables
    run_test "Private Config Structure" test_private_config_template_structure
    run_test "Private Config Variables" test_private_config_template_variables
    run_test "Helm Values Structure" test_helm_values_template_structure
    run_test "Template Substitution" test_template_substitution
    run_test "YAML Validity" test_template_yaml_validity
    run_test "Template Comments" test_template_comments
    run_test "Template Security" test_template_security
    run_test "Private Registry Support" test_template_private_registry_support
    
    # Exit with summary
    exit_with_summary "Template Tests"
}

main