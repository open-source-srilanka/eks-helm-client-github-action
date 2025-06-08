#!/bin/bash
# .github/scripts/testing/validate-action.sh

set -e

# Source shared testing utilities
source "$(dirname "$0")/utils.sh"

# Reset counters for this script
reset_counters

# Helper function to run validations
run_validation() {
    local test_name="$1"
    local test_function="$2"
    
    log_info "Running validation: $test_name"
    
    if $test_function; then
        log_test_result "PASS" "$test_name"
        return 0
    else
        log_test_result "FAIL" "$test_name"
        return 1
    fi
}

validate_action_yml() {
    log_info "Validating action.yml structure..."
    
    if [[ ! -f "action.yml" ]]; then
        log_error "action.yml file not found"
        return 1
    fi
    log_info "✓ action.yml exists"

    # Check required top-level fields
    local required_fields=("name" "description" "runs")
    local all_present=true
    
    for field in "${required_fields[@]}"; do
        if grep -q "^${field}:" action.yml && [[ -n "$(grep "^${field}:" action.yml | cut -d':' -f2- | tr -d ' ')" ]]; then
            log_info "✓ action.yml has '${field}' field"
        else
            log_info "✗ action.yml missing or empty '${field}' field"
            all_present=false
        fi
    done
    
    # Check Docker configuration specifically
    if grep -q "using: 'docker'" action.yml || grep -q 'using: "docker"' action.yml; then
        log_info "✓ Action uses Docker runtime"
        
        if grep -q "image: 'Dockerfile'" action.yml || grep -q 'image: "Dockerfile"' action.yml; then
            log_info "✓ Action references Dockerfile correctly"
        else
            log_info "✗ Action image must reference 'Dockerfile'"
            all_present=false
        fi
    else
        log_info "✗ Action runs.using must be 'docker'"
        all_present=false
    fi
    
    # Check for inputs section
    if grep -q "^inputs:" action.yml; then
        log_info "✓ action.yml has inputs section"
        
        # Check for required inputs
        local required_inputs=("args")
        for input in "${required_inputs[@]}"; do
            if grep -A 10 "^inputs:" action.yml | grep -q "^  ${input}:"; then
                log_info "✓ action.yml has required input '${input}'"
            else
                log_info "✗ action.yml missing required input '${input}'"
                all_present=false
            fi
        done
    else
        log_info "✗ action.yml missing inputs section"
        all_present=false
    fi
    
    # Check branding section (optional but recommended)
    if grep -q "^branding:" action.yml; then
        log_info "✓ action.yml has branding section"
        increment_warnings  # This is good practice but not required
    else
        log_warn "action.yml missing branding section (recommended for marketplace)"
        increment_warnings
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
    
    # Check required Dockerfile instructions
    local required_instructions=("FROM" "ENTRYPOINT")
    local all_present=true
    
    for instruction in "${required_instructions[@]}"; do
        if grep -q "^${instruction}" Dockerfile; then
            log_info "✓ Dockerfile has ${instruction} instruction"
        else
            log_info "✗ Dockerfile missing ${instruction} instruction"
            all_present=false
        fi
    done
    
    # Check FROM instruction uses a valid base image
    local from_line
    from_line=$(grep "^FROM" Dockerfile | head -1)
    if [[ "$from_line" =~ FROM[[:space:]]+[a-zA-Z0-9._/-]+:[a-zA-Z0-9._-]+$ ]] || [[ "$from_line" =~ FROM[[:space:]]+[a-zA-Z0-9._/-]+$ ]]; then
        log_info "✓ Dockerfile FROM instruction format is valid"
    else
        log_warn "Consider using explicit image tags in FROM instruction"
        increment_warnings
    fi
    
    # Check for security best practices
    if grep -q "USER" Dockerfile; then
        log_info "✓ Dockerfile uses non-root user (good security practice)"
    else
        log_warn "Consider using USER instruction for better security"
        increment_warnings
    fi
    
    # Check for LABEL instructions
    if grep -q "^LABEL" Dockerfile; then
        log_info "✓ Dockerfile includes metadata labels"
    else
        log_warn "Consider adding LABEL instructions for better metadata"
        increment_warnings
    fi
    
    # Check for HEALTHCHECK
    if grep -q "^HEALTHCHECK" Dockerfile; then
        log_info "✓ Dockerfile includes health check"
    else
        log_warn "Consider adding HEALTHCHECK instruction"
        increment_warnings
    fi
    
    return $([[ "$all_present" == "true" ]] && echo 0 || echo 1)
}

validate_documentation() {
    log_info "Validating documentation..."
    
    local docs_status=0
    
    # Check README.md
    if [[ -f "README.md" ]]; then
        log_info "✓ README.md exists"
        
        # Check README content
        if [[ -s "README.md" ]]; then
            log_info "✓ README.md is not empty"
            
            # Check for required sections
            local required_sections=("Quick Start" "Inputs" "Usage")
            for section in "${required_sections[@]}"; do
                if grep -qi "$section" README.md; then
                    log_info "✓ README.md contains '$section' section"
                else
                    log_warn "Consider adding '$section' section to README.md"
                    increment_warnings
                fi
            done
            
            # Check for examples
            if grep -qi "example" README.md; then
                log_info "✓ README.md contains examples"
            else
                log_warn "Consider adding usage examples to README.md"
                increment_warnings
            fi
        else
            log_info "✗ README.md is empty"
            docs_status=1
        fi
    else
        log_info "✗ README.md missing (required for marketplace)"
        docs_status=1
    fi
    
    # Check for LICENSE
    if [[ -f "LICENSE" ]] || [[ -f "LICENSE.md" ]] || [[ -f "LICENSE.txt" ]]; then
        log_info "✓ LICENSE file exists"
    else
        log_info "✗ LICENSE file missing (required for marketplace)"
        docs_status=1
    fi
    
    # Check for CHANGELOG
    if [[ -f "CHANGELOG.md" ]] || [[ -f "CHANGELOG.txt" ]]; then
        log_info "✓ CHANGELOG file exists"
    else
        log_warn "Consider adding CHANGELOG.md for version tracking"
        increment_warnings
    fi
    
    # Check for CODE_OF_CONDUCT
    if [[ -f "CODE_OF_CONDUCT.md" ]]; then
        log_info "✓ CODE_OF_CONDUCT.md exists"
    else
        log_warn "Consider adding CODE_OF_CONDUCT.md"
        increment_warnings
    fi
    
    # Check for SECURITY.md
    if [[ -f "SECURITY.md" ]] || [[ -f "docs/SECURITY.md" ]]; then
        log_info "✓ SECURITY.md exists"
    else
        log_warn "Consider adding SECURITY.md"
        increment_warnings
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
            
            # Check if script is executable
            if [[ -x "$script" ]]; then
                log_info "✓ Script is executable: $script"
            else
                log_info "✗ Script is not executable: $script"
                scripts_status=1
            fi
            
            # Check shebang
            if head -1 "$script" | grep -q "^#!/bin/bash"; then
                log_info "✓ Script has proper shebang: $script"
            else
                log_warn "Script $script should use #!/bin/bash shebang"
                increment_warnings
            fi
            
            # Basic syntax check
            if bash -n "$script" 2>/dev/null; then
                log_info "✓ Script syntax is valid: $script"
            else
                log_info "✗ Script has syntax errors: $script"
                scripts_status=1
            fi
            
            # Check for set -e (good practice)
            if grep -q "set -e" "$script"; then
                log_info "✓ Script uses 'set -e': $script"
            else
                log_warn "Consider using 'set -e' in $script"
                increment_warnings
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
            local required_vars=("\${CLUSTER_NAME}" "\${REGION_CODE}" "\${ENDPOINT_URL}" "\${CA_CERT}")
            for var in "${required_vars[@]}"; do
                if grep -q "$var" "$template"; then
                    log_info "✓ Template $template contains $var"
                else
                    log_info "✗ Template $template missing $var"
                    templates_status=1
                fi
            done
            
            # Check for YAML structure (basic)
            if grep -q "apiVersion:" "$template" && grep -q "kind:" "$template"; then
                log_info "✓ Template $template has proper YAML structure"
            else
                log_info "✗ Template $template missing proper YAML structure"
                templates_status=1
            fi
        else
            log_info "✗ Template missing: $template"
            templates_status=1
        fi
    done
    
    return $templates_status
}

validate_github_workflows() {
    log_info "Validating GitHub workflows..."
    
    local workflows_status=0
    local workflows=(".github/workflows/test.yaml" ".github/workflows/release.yaml" ".github/workflows/security.yaml")
    
    for workflow in "${workflows[@]}"; do
        if [[ -f "$workflow" ]]; then
            log_info "✓ Workflow exists: $workflow"
            
            # Basic YAML structure check
            if grep -q "^name:" "$workflow" && grep -q "^on:" "$workflow" && grep -q "^jobs:" "$workflow"; then
                log_info "✓ Workflow $workflow has proper structure"
            else
                log_info "✗ Workflow $workflow missing required structure"
                workflows_status=1
            fi
            
            # Check for permissions (security best practice)
            if grep -q "permissions:" "$workflow"; then
                log_info "✓ Workflow $workflow defines permissions"
            else
                log_warn "Consider defining permissions in $workflow"
                increment_warnings
            fi
        else
            log_info "✗ Workflow missing: $workflow"
            workflows_status=1
        fi
    done
    
    # Check for required workflow files
    if [[ -f ".github/workflows/test.yaml" ]] || [[ -f ".github/workflows/test.yml" ]]; then
        log_info "✓ Test workflow exists"
    else
        log_info "✗ Test workflow missing"
        workflows_status=1
    fi
    
    return $workflows_status
}

validate_gitignore() {
    log_info "Validating .gitignore..."
    
    if [[ -f ".gitignore" ]]; then
        log_info "✓ .gitignore exists"
        
        # Check for common patterns that should be ignored
        local important_patterns=("node_modules" "*.log" "*.tmp" ".env" "*.secret")
        for pattern in "${important_patterns[@]}"; do
            if grep -q "$pattern" .gitignore; then
                log_info "✓ .gitignore includes $pattern"
            else
                log_warn "Consider adding $pattern to .gitignore"
                increment_warnings
            fi
        done
    else
        log_warn ".gitignore file missing"
        increment_warnings
    fi
    
    return 0
}

validate_security_files() {
    log_info "Validating security configuration..."
    
    local security_status=0
    
    # Check for .dockerignore
    if [[ -f ".dockerignore" ]]; then
        log_info "✓ .dockerignore exists"
        
        # Check that sensitive files are ignored
        local sensitive_patterns=(".env" "*.key" "*.pem" "secrets")
        for pattern in "${sensitive_patterns[@]}"; do
            if grep -q "$pattern" .dockerignore; then
                log_info "✓ .dockerignore excludes $pattern"
            else
                log_warn "Consider adding $pattern to .dockerignore"
                increment_warnings
            fi
        done
    else
        log_warn ".dockerignore missing (recommended for security)"
        increment_warnings
    fi
    
    # Check for security policy
    if [[ -f "SECURITY.md" ]] || [[ -f ".github/SECURITY.md" ]] || [[ -f "docs/SECURITY.md" ]]; then
        log_info "✓ Security policy exists"
    else
        log_warn "Consider adding SECURITY.md"
        increment_warnings
    fi
    
    return $security_status
}

main() {
    log_info "=== GitHub Action Validation ==="
    
    # Run all validations
    run_validation "action.yml Structure" validate_action_yml
    run_validation "Dockerfile" validate_dockerfile
    run_validation "Documentation" validate_documentation
    run_validation "Scripts" validate_scripts
    run_validation "Templates" validate_templates
    run_validation "GitHub Workflows" validate_github_workflows
    run_validation "Git Configuration" validate_gitignore
    run_validation "Security Configuration" validate_security_files
    
    # Exit with summary
    exit_with_summary "Action Validation"
}

main