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

    # Check required top-level fields
    local required_fields=("name" "description" "runs")
    local all_present=true
    
    for field in "${required_fields[@]}"; do
        if grep -q "^${field}:" action.yml && [[ -n "$(grep "^${field}:" action.yml | cut -d':' -f2- | tr -d ' ')" ]]; then
            log_message "PASS" "action.yml has '${field}'"
        else
            log_message "FAIL" "action.yml has '${field}'" "Field missing or empty"
            all_present=false
        fi
    done
    
    # Check Docker configuration specifically
    if grep -q "using: 'docker'" action.yml || grep -q 'using: "docker"' action.yml; then
        log_message "PASS" "Action uses Docker runtime"
        
        if grep -q "image: 'Dockerfile'" action.yml || grep -q 'image: "Dockerfile"' action.yml; then
            log_message "PASS" "Action references Dockerfile correctly"
        else
            log_message "FAIL" "Action Docker image" "Image must reference 'Dockerfile'"
            all_present=false
        fi
    else
        log_message "FAIL" "Action uses Docker" "runs.using must be 'docker'"
        all_present=false
    fi
    
    # Check for inputs section
    if grep -q "^inputs:" action.yml; then
        log_message "PASS" "action.yml has inputs section"
        
        # Check for required inputs
        local required_inputs=("args")
        for input in "${required_inputs[@]}"; do
            if grep -A 5 "^inputs:" action.yml | grep -q "^  ${input}:"; then
                log_message "PASS" "action.yml has required input '${input}'"
            else
                log_message "FAIL" "action.yml has required input '${input}'" "Input missing"
                all_present=false
            fi
        done
    else
        log_message "FAIL" "action.yml has inputs section" "Inputs section missing"
        all_present=false
    fi
    
    return $([[ "$all_present" == "true" ]] && echo 0 || echo 1)
}

validate_dockerfile() {
    log_message "INFO" "Validating Dockerfile..."
    
    if [[ ! -f "Dockerfile" ]]; then
        log_message "FAIL" "Dockerfile exists" "File not found"
        return 1
    fi
    log_message "PASS" "Dockerfile exists"
    
    # Check required Dockerfile instructions
    local required_instructions=("FROM" "ENTRYPOINT")
    local all_present=true
    
    for instruction in "${required_instructions[@]}"; do
        if grep -q "^${instruction}" Dockerfile; then
            log_message "PASS" "Dockerfile has ${instruction} instruction"
        else
            log_message "FAIL" "Dockerfile has ${instruction} instruction" "Instruction missing"
            all_present=false
        fi
    done
    
    # Check FROM instruction uses a valid base image
    local from_line
    from_line=$(grep "^FROM" Dockerfile | head -1)
    if [[ "$from_line" =~ FROM[[:space:]]+[a-zA-Z0-9._/-]+:[a-zA-Z0-9._-]+$ ]] || [[ "$from_line" =~ FROM[[:space:]]+[a-zA-Z0-9._/-]+$ ]]; then
        log_message "PASS" "Dockerfile FROM instruction format"
    else
        log_message "WARN" "Dockerfile FROM instruction format" "Consider using explicit image tags"
    fi
    
    # Check for security best practices
    if grep -q "USER" Dockerfile; then
        log_message "PASS" "Dockerfile uses non-root user"
    else
        log_message "WARN" "Dockerfile security" "Consider using USER instruction for better security"
    fi
    
    # Check for LABEL instructions
    if grep -q "^LABEL" Dockerfile; then
        log_message "PASS" "Dockerfile includes metadata labels"
    else
        log_message "WARN" "Dockerfile metadata" "Consider adding LABEL instructions for better metadata"
    fi
    
    return $([[ "$all_present" == "true" ]] && echo 0 || echo 1)
}

validate_documentation() {
    log_message "INFO" "Validating documentation..."
    
    local docs_status=0
    
    # Check README.md
    if [[ -f "README.md" ]]; then
        log_message "PASS" "README.md exists"
        
        # Check README content
        if [[ -s "README.md" ]]; then
            log_message "PASS" "README.md is not empty"
            
            # Check for required sections
            local required_sections=("Quick Start" "Inputs" "Usage")
            for section in "${required_sections[@]}"; do
                if grep -qi "$section" README.md; then
                    log_message "PASS" "README.md contains '$section' section"
                else
                    log_message "WARN" "README.md structure" "Consider adding '$section' section"
                fi
            done
        else
            log_message "FAIL" "README.md content" "File is empty"
            docs_status=1
        fi
    else
        log_message "FAIL" "README.md exists" "Required for marketplace publication"
        docs_status=1
    fi
    
    # Check for LICENSE
    if [[ -f "LICENSE" ]] || [[ -f "LICENSE.md" ]] || [[ -f "LICENSE.txt" ]]; then
        log_message "PASS" "LICENSE file exists"
    else
        log_message "FAIL" "LICENSE file exists" "Required for marketplace publication"
        docs_status=1
    fi
    
    # Check for CHANGELOG
    if [[ -f "CHANGELOG.md" ]] || [[ -f "CHANGELOG.txt" ]]; then
        log_message "PASS" "CHANGELOG file exists"
    else
        log_message "WARN" "CHANGELOG file" "Consider adding a changelog for version tracking"
    fi
    
    return $docs_status
}

validate_scripts() {
    log_message "INFO" "Validating scripts..."
    
    local scripts_status=0
    local scripts=("scripts/entrypoint.sh" "scripts/health-check.sh" "scripts/setup-tools.sh" "scripts/cleanup.sh")
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            log_message "PASS" "Script exists: $script"
            
            # Check if script is executable
            if [[ -x "$script" ]]; then
                log_message "PASS" "Script is executable: $script"
            else
                log_message "FAIL" "Script permissions: $script" "Script is not executable"
                scripts_status=1
            fi
            
            # Check shebang
            if head -1 "$script" | grep -q "^#!/bin/bash"; then
                log_message "PASS" "Script has proper shebang: $script"
            else
                log_message "WARN" "Script shebang: $script" "Consider using #!/bin/bash"
            fi
            
            # Basic syntax check
            if bash -n