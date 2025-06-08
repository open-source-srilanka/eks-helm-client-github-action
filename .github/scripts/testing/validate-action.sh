#!/bin/bash
# .github/scripts/testing/validate-action.sh

set -e

# Source shared testing utilities
source "$(dirname "$0")/utils.sh"

# Initialize utils and reset counters
init_utils "${INPUT_DEBUG:-false}"

# Main validation functions
validate_action_yml() {
    log_info "Validating action.yml structure..."
    
    if [[ ! -f "action.yml" ]]; then
        log_error "action.yml file not found"
        return 1
    fi
    log_info "✓ action.yml exists"

    local all_present=true
    
    # Check required top-level fields with flexible detection
    local required_fields=("name" "description" "runs")
    for field in "${required_fields[@]}"; do
        if grep -q "^${field}:" action.yml || grep -q "^[[:space:]]*${field}:" action.yml; then
            local field_value
            field_value=$(grep "^[[:space:]]*${field}:" action.yml | head -1 | cut -d':' -f2- | sed 's/^[[:space:]]*//' | sed 's/["\047]//g')
            if [[ -n "$field_value" ]]; then
                log_info "✓ action.yml has '${field}' field: $field_value"
            else
                log_info "✗ action.yml has '${field}' field but it's empty"
                all_present=false
            fi
        else
            log_info "✗ action.yml missing '${field}' field"
            all_present=false
        fi
    done
    
    # Check Docker configuration
    if grep -q "using.*docker" action.yml; then
        log_info "✓ Action uses Docker runtime"
    else
        log_info "✗ Action runs.using must be 'docker'"
        all_present=false
    fi
    
    if grep -q "image.*Dockerfile" action.yml; then
        log_info "✓ Action references Dockerfile correctly"
    else
        log_info "✗ Action image must reference 'Dockerfile'"
        all_present=false
    fi
    
    # Check for inputs section
    if grep -q "inputs:" action.yml; then
        log_info "✓ action.yml has inputs section"
        
        # Check for args input
        if grep -A 20 "inputs:" action.yml | grep -q "args:"; then
            log_info "✓ action.yml has required input 'args'"
        else
            log_info "✗ action.yml missing required input 'args'"
            all_present=false
        fi
    else
        log_info "✗ action.yml missing inputs section"
        all_present=false
    fi
    
    # Check branding section (optional)
    if grep -q "branding:" action.yml; then
        log_info "✓ action.yml has branding section"
    else
        log_warn "action.yml missing branding section (recommended for marketplace)"
    fi
    
    return $([[ "$all_present" == "true" ]] && echo 0 || echo 1)
}

validate_dockerfile() {
    log_info "Validating Dockerfile..."
    
    if [[ ! -f "Dockerfile" ]]; then
        log_error "Dockerfile not found"
        return 1
    fi
    log_info "✓ Dockerfile exists"
    
    local all_present=true
    
    # Check required instructions
    if grep -q "^FROM" Dockerfile; then
        log_info "✓ Dockerfile has FROM instruction"
    else
        log_info "✗ Dockerfile missing FROM instruction"
        all_present=false
    fi
    
    if grep -q "^ENTRYPOINT\|^CMD" Dockerfile; then
        log_info "✓ Dockerfile has entry point instruction"
    else
        log_info "✗ Dockerfile missing ENTRYPOINT or CMD instruction"
        all_present=false
    fi
    
    # Check best practices
    if grep -q "USER" Dockerfile; then
        log_info "✓ Dockerfile uses non-root user"
    else
        log_warn "Consider using USER instruction for better security"
    fi
    
    if grep -q "^LABEL" Dockerfile; then
        log_info "✓ Dockerfile includes metadata labels"
    else
        log_warn "Consider adding LABEL instructions"
    fi
    
    if grep -q "^HEALTHCHECK" Dockerfile; then
        log_info "✓ Dockerfile includes health check"
    else
        log_warn "Consider adding HEALTHCHECK instruction"
    fi
    
    return $([[ "$all_present" == "true" ]] && echo 0 || echo 1)
}

validate_documentation() {
    log_info "Validating documentation..."
    
    local docs_status=0
    
    # Check README.md
    if [[ -f "README.md" && -s "README.md" ]]; then
        log_info "✓ README.md exists and is not empty"
        
        if grep -qi "usage\|example\|quick start" README.md; then
            log_info "✓ README.md contains usage information"
        else
            log_warn "Consider adding usage examples to README.md"
        fi
    else
        log_info "✗ README.md missing or empty"
        docs_status=1
    fi
    
    # Check LICENSE
    if [[ -f "LICENSE" || -f "LICENSE.md" || -f "LICENSE.txt" ]]; then
        log_info "✓ LICENSE file exists"
    else
        log_info "✗ LICENSE file missing"
        docs_status=1
    fi
    
    # Check CHANGELOG
    if [[ -f "CHANGELOG.md" ]]; then
        log_info "✓ CHANGELOG file exists"
    else
        log_warn "Consider adding CHANGELOG.md"
    fi
    
    return $docs_status
}

validate_scripts() {
    log_info "Validating scripts..."
    
    local scripts_status=0
    local scripts=("scripts/entrypoint.sh" "scripts/health-check.sh" "scripts/setup-tools.sh" "scripts/cleanup.sh")
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            log_info "✓ Script exists: $script"
            
            if [[ -x "$script" ]]; then
                log_info "✓ Script is executable: $script"
            else
                log_info "✗ Script is not executable: $script"
                scripts_status=1
            fi
            
            if bash -n "$script" 2>/dev/null; then
                log_info "✓ Script syntax is valid: $script"
            else
                log_info "✗ Script has syntax errors: $script"
                scripts_status=1
            fi
        else
            log_info "✗ Script missing: $script"
            scripts_status=1
        fi
    done
    
    return $scripts_status
}

validate_templates() {
    log_info "Validating configuration templates..."
    
    local templates_status=0
    local templates=("templates/config.template" "templates/private-config.template")
    
    for template in "${templates[@]}"; do
        if [[ -f "$template" ]]; then
            log_info "✓ Template exists: $template"
            
            # Check for required variables
            if grep -q "\${CLUSTER_NAME}" "$template" && grep -q "\${REGION_CODE}" "$template"; then
                log_info "✓ Template $template contains required variables"
            else
                log_info "✗ Template $template missing required variables"
                templates_status=1
            fi
        else
            log_info "✗ Template missing: $template"
            templates_status=1
        fi
    done
    
    return $templates_status
}

validate_workflows() {
    log_info "Validating GitHub workflows..."
    
    local workflows_status=0
    
    # Check for test workflow
    if [[ -f ".github/workflows/test.yaml" || -f ".github/workflows/test.yml" ]]; then
        log_info "✓ Test workflow exists"
    else
        log_info "✗ Test workflow missing"
        workflows_status=1
    fi
    
    # Check other workflows
    local workflows=(".github/workflows/test.yaml" ".github/workflows/release.yaml" ".github/workflows/security.yaml")
    for workflow in "${workflows[@]}"; do
        if [[ -f "$workflow" ]]; then
            log_info "✓ Workflow exists: $workflow"
            if grep -q "^name:\|^on:" "$workflow"; then
                log_info "✓ Workflow $workflow has proper structure"
            else
                log_info "✗ Workflow $workflow missing required structure"
                workflows_status=1
            fi
        fi
    done
    
    return $workflows_status
}

validate_security() {
    log_info "Validating security configuration..."
    
    # Check for security files
    if [[ -f ".dockerignore" ]]; then
        log_info "✓ .dockerignore exists"
    else
        log_warn ".dockerignore missing (recommended)"
    fi
    
    if [[ -f ".gitignore" ]]; then
        log_info "✓ .gitignore exists"
    else
        log_warn ".gitignore missing"
    fi
    
    if [[ -f "SECURITY.md" || -f "docs/SECURITY.md" ]]; then
        log_info "✓ Security policy exists"
    else
        log_warn "Consider adding SECURITY.md"
    fi
    
    return 0
}

main() {
    log_info "=== GitHub Action Validation ==="
    
    # Run all validations using the safe test runner
    run_test_safe "action.yml Structure" validate_action_yml
    run_test_safe "Dockerfile" validate_dockerfile
    run_test_safe "Documentation" validate_documentation
    run_test_safe "Scripts" validate_scripts
    run_test_safe "Templates" validate_templates
    run_test_safe "GitHub Workflows" validate_workflows
    run_test_safe "Security Configuration" validate_security
    
    # Exit with summary
    exit_with_summary "Action Validation"
}

main