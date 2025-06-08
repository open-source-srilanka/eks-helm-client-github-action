#!/bin/bash
# .github/scripts/testing/utils.sh
# Shared utilities for testing scripts

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Global test counters - scripts using this should initialize them
TESTS_PASSED=${TESTS_PASSED:-0}
TESTS_FAILED=${TESTS_FAILED:-0}
TESTS_SKIPPED=${TESTS_SKIPPED:-0}
WARNINGS=${WARNINGS:-0}
CHECKS_PASSED=${CHECKS_PASSED:-0}
CHECKS_FAILED=${CHECKS_FAILED:-0}


# Function to log test results
# Usage: log_message "STATUS" "Test Name" "Optional Message"
log_message() {
    local status=$1
    local name=$2
    local message=${3:-""}

    case $status in
        "PASS")
            echo -e "${GREEN}✓${NC} $name"
            ((TESTS_PASSED++))
            ((CHECKS_PASSED++))
            ;;
        "FAIL")
            echo -e "${RED}✗${NC} $name: $message"
            ((TESTS_FAILED++))
            ((CHECKS_FAILED++))
            ;;
        "SKIP")
            echo -e "${YELLOW}○${NC} $name: $message"
            ((TESTS_SKIPPED++))
            ;;
        "WARN")
            echo -e "${YELLOW}⚠${NC} $name: $message"
            ((WARNINGS++))
            ;;
        "INFO")
            echo -e "${BLUE}i${NC} $name: $message"
            ;;
    esac
}