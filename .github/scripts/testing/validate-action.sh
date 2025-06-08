#!/bin/bash
# .github/scripts/testing/validate-action.sh
# Validate the GitHub Action configuration and marketplace readiness

set -e

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Validation counters
CHECKS_PASSED=0
CHECKS_FAILED=0
WARNINGS=0

# Validation results
VALIDATION_RESULTS=""

# Function to log validation results
log_check() {
    local check_name=$1
    local status=$2
    local message=${3:-""}
    
    case $status in
        "PASS")
            echo -e "${GREEN}✓${NC} $check_name"
            ((CHECKS_PASSED++))
            VALIDATION_RESULTS="${VALIDATION_RESULTS}\n✓ $check_name"
            ;;
        "FAIL")
            echo -e "${RED}✗${NC} $check_name: $message"
            ((CHECKS_FAILED++))
            VALIDATION_RESULTS="${VALIDATION_RESULTS}\n✗ $check_name: $message"
            ;;
        "WARN")
            echo -e "${YELLOW}⚠${NC} $check_name: $message"
            ((WARNINGS++))
            VALIDATION_RESULTS="${VALIDATION_RESULTS}\n⚠ $check_name: $message"
            ;;
    esac
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validate action.yml structure
validate_action_yml() {
    echo -e "${BLUE}Validating action.yml structure...${NC}"
    
    if [[ ! -f "action.yml" ]]; then
        log_check "action.yml exists" "FAIL" "File not found"
        return 1
    else
        log_check "action.yml exists" "PASS"
    fi
    
    # Check required top-level fields
    local required_fields=("name" "description" "author" "runs")
    for field in "${required_fields[@]}"; do
        if grep -q "^$field:" action.yml; then
            local value=$(grep "^$field:" action.yml | cut -d':' -f2- | sed 's/^ *//;s/ *$//' | tr -d "'\"")
            if [[ -n "$value" && "$value" != "null" ]]; then
                log_check "action.yml has '$field'" "PASS"
            else
                log_check "action.yml has '$field'" "FAIL" "Field is empty"
            fi
        else
            log_check "action.yml has '$field'" "FAIL" "Field missing"
        fi
    done
    
    # Check branding (required for marketplace)
    if grep -q "^branding:" action.yml; then
        log_check "action.yml has branding" "PASS"
        
        # Check icon
        if grep -A5 "^branding:" action.yml | grep -q "icon:"; then
            local icon=$(grep -A5 "^branding:" action.yml | grep "icon:" | cut -d':' -f2 | sed 's/^ *//;s/ *$//' | tr -d "'\"")
            if [[ -n "$icon" ]]; then
                log_check "Branding has icon" "PASS" "Icon: $icon"
            else
                log_check "Branding has icon" "FAIL" "Icon is empty"
            fi
        else
            log_check "Branding has icon" "FAIL" "Icon missing"
        fi
        
        # Check color
        if grep -A5 "^branding:" action.yml | grep -q "color:"; then
            local color=$(grep -A5 "^branding:" action.yml | grep "color:" | cut -d':' -f2 | sed 's/^ *//;s/ *$//' | tr -d "'\"")
            if [[ -n "$color" ]]; then
                # Validate color is one of GitHub's allowed colors
                local valid_colors=("white" "yellow" "blue" "green" "orange" "red" "purple" "gray-dark")
                if [[ " ${valid_colors[@]} " =~ " ${color} " ]]; then
                    log_check "Branding has valid color" "PASS" "Color: $color"
                else
                    log_check "Branding has valid color" "FAIL" "Invalid color: $color"
                fi
            else
                log_check "Branding has color" "FAIL" "Color is empty"
            fi
        else
            log_check "Branding has color" "FAIL" "Color missing"
        fi
    else
        log_check "action.yml has branding" "FAIL" "Branding section missing (required for marketplace)"
    fi
    
    # Check runs configuration
    if grep -q "using: 'docker'" action.yml; then
        log_check "Action uses Docker" "PASS"
        
        # Check Dockerfile reference
        if grep -q "image: 'Dockerfile'" action.yml; then
            log_check "References Dockerfile" "PASS"
        else
            log_check "References Dockerfile" "FAIL" "Must reference 'Dockerfile'"
        fi
    else
        log_check "Action uses Docker" "FAIL" "Must use 'docker' for runs.using"
    fi
}

# Validate inputs
validate_inputs() {
    echo -e "\n${BLUE}Validating action inputs...${NC}"
    
    # Required inputs that should be defined
    local expected_inputs=(
        "args"
        "cluster-name"
        "region"
        "private-cluster"
        "helm-registry-url"
        "helm-registry-username"
        "helm-registry-password"
        "kubectl-version"
        "helm-version"
        "timeout"
        "debug"
        "dry-run"
    )
    
    for input in "${expected_inputs[@]}"; do
        if grep -q "  $input:" action.yml; then
            # Check if input has description
            if grep -A2 "  $input:" action.yml | grep -q "description:"; then
                log_check "Input '$input' has description" "PASS"
            else
                log_check "Input '$input' has description" "WARN" "Missing description"
            fi
            
            # Check if required field is set correctly
            if [[ "$input" == "args" ]]; then
                if grep -A3 "  $input:" action.yml | grep -q "required: true"; then
                    log_check "Input '$input' marked as required" "PASS"
                else
                    log_check "Input '$input' marked as required" "FAIL" "Should be required"
                fi
            fi
        else
            log_check "Input '$input' defined" "FAIL" "Input not found"
        fi
    done
}

# Validate Dockerfile
validate_dockerfile() {
    echo -e "\n${BLUE}Validating Dockerfile...${NC}"
    
    if [[ ! -f "Dockerfile" ]]; then
        log_check "Dockerfile exists" "FAIL" "File not found"
        return 1
    else
        log_check "Dockerfile exists" "PASS"
    fi
    
    # Check base image
    if grep -q "^FROM alpine:" Dockerfile; then
        log_check "Uses Alpine base image" "PASS"
    else
        log_check "Uses Alpine base image" "WARN" "Consider using Alpine for smaller image"
    fi
    
    # Check for LABEL instructions
    if grep -q "^LABEL maintainer=" Dockerfile; then
        log_check "Has maintainer label" "PASS"
    else
        log_check "Has maintainer label" "WARN" "Consider adding maintainer label"
    fi
    
    # Check for version label
    if grep -q "^LABEL version=" Dockerfile; then
        log_check "Has version label" "PASS"
    else
        log_check "Has version label" "WARN" "Consider adding version label"
    fi
    
    # Check entrypoint
    if grep -q "^ENTRYPOINT.*entrypoint.sh" Dockerfile; then
        log_check "Sets entrypoint" "PASS"
    else
        log_check "Sets entrypoint" "FAIL" "Must set ENTRYPOINT"
    fi
    
    # Check for security best practices
    if grep -q "^USER " Dockerfile; then
        log_check "Runs as non-root user" "PASS"
    else
        log_check "Runs as non-root user" "WARN" "Consider running as non-root"
    fi
    
    # Check for HEALTHCHECK
    if grep -q "^HEALTHCHECK" Dockerfile; then
        log_check "Has health check" "PASS"
    else
        log_check "Has health check" "WARN" "Consider adding HEALTHCHECK"
    fi
}

# Validate documentation
validate_documentation() {
    echo -e "\n${BLUE}Validating documentation...${NC}"
    
    # Check README.md
    if [[ -f "README.md" ]]; then
        log_check "README.md exists" "PASS"
        
        # Check for required sections
        local readme_sections=(
            "Features"
            "Quick Start"
            "Usage"
            "Inputs"
            "Examples"
        )
        
        for section in "${readme_sections[@]}"; do
            if grep -qi "^#.*$section" README.md; then
                log_check "README has '$section' section" "PASS"
            else
                log_check "README has '$section' section" "WARN" "Consider adding this section"
            fi
        done
        
        # Check for badges
        if grep -q "\[!\[.*\].*\]" README.md; then
            log_check "README has badges" "PASS"
        else
            log_check "README has badges" "WARN" "Consider adding status badges"
        fi
    else
        log_check "README.md exists" "FAIL" "Required for marketplace"
    fi
    
    # Check LICENSE
    if [[ -f "LICENSE" ]] || [[ -f "LICENSE.md" ]]; then
        log_check "LICENSE file exists" "PASS"
    else
        log_check "LICENSE file exists" "FAIL" "Required for marketplace"
    fi
    
    # Check CHANGELOG
    if [[ -f "CHANGELOG.md" ]]; then
        log_check "CHANGELOG.md exists" "PASS"
    else
        log_check "CHANGELOG.md exists" "WARN" "Recommended for version tracking"
    fi
}

# Validate security files
validate_security() {
    echo -e "\n${BLUE}Validating security configuration...${NC}"
    
    # Check for security policy
    if [[ -f "SECURITY.md" ]] || [[ -f "docs/SECURITY.md" ]] || [[ -f ".github/SECURITY.md" ]]; then
        log_check "SECURITY.md exists" "PASS"
    else
        log_check "SECURITY.md exists" "WARN" "Consider adding security policy"
    fi
    
    # Check for code scanning
    if [[ -f ".github/workflows/security.yml" ]] || [[ -f ".github/workflows/security.yaml" ]]; then
        log_check "Security workflow exists" "PASS"
    else
        log_check "Security workflow exists" "WARN" "Consider adding security scanning"
    fi
    
    # Check .gitignore
    if [[ -f ".gitignore" ]]; then
        log_check ".gitignore exists" "PASS"
        
        # Check for sensitive patterns
        local sensitive_patterns=(".env" "*.key" "*.pem" "secrets/")
        for pattern in "${sensitive_patterns[@]}"; do
            if grep -q "$pattern" .gitignore; then
                log_check ".gitignore includes '$pattern'" "PASS"
            else
                log_check ".gitignore includes '$pattern'" "WARN" "Consider adding to .gitignore"
            fi
        done
    else
        log_check ".gitignore exists" "FAIL" "Required for security"
    fi
}

# Validate marketplace requirements
validate_marketplace_requirements() {
    echo -e "\n${BLUE}Validating GitHub Marketplace requirements...${NC}"
    
    # Check action name length (max 50 chars)
    local action_name=$(grep "^name:" action.yml | cut -d':' -f2- | sed 's/^ *//;s/ *$//' | tr -d "'\"")
    if [[ ${#action_name} -le 50 ]]; then
        log_check "Action name length" "PASS" "Length: ${#action_name}/50"
    else
        log_check "Action name length" "FAIL" "Too long: ${#action_name}/50 characters"
    fi
    
    # Check description length (max 125 chars)
    local description=$(grep "^description:" action.yml | cut -d':' -f2- | sed 's/^ *//;s/ *$//' | tr -d "'\"")
    if [[ ${#description} -le 125 ]]; then
        log_check "Description length" "PASS" "Length: ${#description}/125"
    else
        log_check "Description length" "FAIL" "Too long: ${#description}/125 characters"
    fi
    
    # Check for unique action name
    if [[ "$action_name" =~ "EKS Helm" ]]; then
        log_check "Action name is descriptive" "PASS"
    else
        log_check "Action name is descriptive" "WARN" "Consider more descriptive name"
    fi
}

# Validate file permissions
validate_file_permissions() {
    echo -e "\n${BLUE}Validating file permissions...${NC}"
    
    # Check script permissions
    local scripts=(
        "scripts/entrypoint.sh"
        "scripts/health-check.sh"
        "scripts/setup-tools.sh"
        "scripts/cleanup.sh"
        ".github/scripts/release/*.sh"
        ".github/scripts/testing/*.sh"
    )
    
    for script_pattern in "${scripts[@]}"; do
        # Use find to handle wildcards
        while IFS= read -r script; do
            if [[ -f "$script" ]]; then
                if [[ -x "$script" ]]; then
                    log_check "Script '$script' is executable" "PASS"
                else
                    log_check "Script '$script' is executable" "FAIL" "Run: chmod +x $script"
                fi
            fi
        done < <(find . -path "./$script_pattern" -type f 2>/dev/null || echo "./$script_pattern")
    done
}

# Validate version consistency
validate_version_consistency() {
    echo -e "\n${BLUE}Validating version consistency...${NC}"
    
    # Extract versions from different files
    local dockerfile_version=""
    local changelog_version=""
    local readme_version=""
    
    # Get version from Dockerfile
    if [[ -f "Dockerfile" ]]; then
        dockerfile_version=$(grep "LABEL version=" Dockerfile | cut -d'"' -f2 2>/dev/null || echo "")
    fi
    
    # Get latest version from CHANGELOG
    if [[ -f "CHANGELOG.md" ]]; then
        changelog_version=$(grep -m1 "^## \[.*\]" CHANGELOG.md | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+" | head -1 || echo "")
    fi
    
    # Get version from README badge
    if [[ -f "README.md" ]]; then
        readme_version=$(grep -o "version-v[0-9]\+\.[0-9]\+\.[0-9]\+" README.md | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+" | head -1 || echo "")
    fi
    
    # Compare versions
    if [[ -n "$dockerfile_version" && -n "$changelog_version" ]]; then
        if [[ "$dockerfile_version" == "$changelog_version" ]]; then
            log_check "Dockerfile and CHANGELOG versions match" "PASS" "v$dockerfile_version"
        else
            log_check "Dockerfile and CHANGELOG versions match" "WARN" "Dockerfile: v$dockerfile_version, CHANGELOG: v$changelog_version"
        fi
    fi
}

# Validate examples
validate_examples() {
    echo -e "\n${BLUE}Validating examples...${NC}"
    
    # Check for example workflows
    local example_files=(
        "docs/examples/basic-usage.md"
        "docs/examples/private-cluster.md"
        "docs/examples/private-registry.md"
    )
    
    for example in "${example_files[@]}"; do
        if [[ -f "$example" ]]; then
            log_check "Example '$example' exists" "PASS"
        else
            log_check "Example '$example' exists" "WARN" "Consider adding example"
        fi
    done
    
    # Check README for usage examples
    if grep -q "uses:.*eks-helm-client-github-action" README.md; then
        log_check "README contains usage examples" "PASS"
    else
        log_check "README contains usage examples" "WARN" "Add usage examples to README"
    fi
}

# Validate dependencies
validate_dependencies() {
    echo -e "\n${BLUE}Validating dependencies...${NC}"
    
    # Check if required tools are mentioned in Dockerfile
    local required_tools=("kubectl" "helm" "aws-cli")
    for tool in "${required_tools[@]}"; do
        if grep -qi "$tool" Dockerfile; then
            log_check "Dockerfile installs '$tool'" "PASS"
        else
            log_check "Dockerfile installs '$tool'" "FAIL" "Required tool not found"
        fi
    done
}

# Generate validation report
generate_report() {
    local report_file="${1:-validation-report.txt}"
    
    {
        echo "GitHub Action Validation Report"
        echo "================================"
        echo "Date: $(date)"
        echo ""
        echo "Summary:"
        echo "  Passed: $CHECKS_PASSED"
        echo "  Failed: $CHECKS_FAILED"
        echo "  Warnings: $WARNINGS"
        echo ""
        echo "Details:"
        echo -e "$VALIDATION_RESULTS"
        echo ""
        
        if [[ $CHECKS_FAILED -eq 0 ]]; then
            echo "✅ Action is ready for GitHub Marketplace!"
        else
            echo "❌ Action has issues that need to be fixed before marketplace submission."
        fi
    } > "$report_file"
    
    echo -e "\n${BLUE}Report saved to: $report_file${NC}"
}

# Main validation
main() {
    echo -e "${BLUE}=== GitHub Action Validation ===${NC}"
    echo -e "${BLUE}Validating EKS Helm Client GitHub Action...${NC}\n"
    
    # Run all validations
    validate_action_yml
    validate_inputs
    validate_dockerfile
    validate_documentation
    validate_security
    validate_marketplace_requirements
    validate_file_permissions
    validate_version_consistency
    validate_examples
    validate_dependencies
    
    # Display summary
    echo -e "\n${BLUE}=== Validation Summary ===${NC}"
    echo -e "${GREEN}Passed:${NC} $CHECKS_PASSED"
    echo -e "${RED}Failed:${NC} $CHECKS_FAILED"
    echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
    
    # Generate report
    generate_report
    
    # Exit with appropriate code
    if [[ $CHECKS_FAILED -gt 0 ]]; then
        echo -e "\n${RED}❌ Validation failed! Please fix the issues above.${NC}"
        exit 1
    else
        if [[ $WARNINGS -gt 0 ]]; then
            echo -e "\n${YELLOW}⚠️  Validation passed with warnings. Consider addressing them for better quality.${NC}"
        else
            echo -e "\n${GREEN}✅ Validation passed! Your action is ready for GitHub Marketplace.${NC}"
        fi
        exit 0
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi