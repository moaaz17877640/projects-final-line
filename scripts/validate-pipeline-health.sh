#!/bin/bash

# Pipeline Health Validation Script
# This script validates the health of the CI/CD pipeline and all components

echo "🔍 PIPELINE HEALTH VALIDATION STARTING..."
echo "========================================"

cd "$(dirname "$0")"
SCRIPT_DIR="$(pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Validation counters
PASSED=0
FAILED=0
WARNINGS=0

# Function to log results
log_result() {
    local status=$1
    local message=$2
    case $status in
        "PASS")
            echo -e "${GREEN}✅ PASS${NC}: $message"
            ((PASSED++))
            ;;
        "FAIL")
            echo -e "${RED}❌ FAIL${NC}: $message"
            ((FAILED++))
            ;;
        "WARN")
            echo -e "${YELLOW}⚠️  WARN${NC}: $message"
            ((WARNINGS++))
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  INFO${NC}: $message"
            ;;
    esac
}

# Check if we're in the right directory
if [[ ! -f "$PROJECT_ROOT/ansible/inventory" ]]; then
    log_result "FAIL" "Not in Employee Management project directory"
    exit 1
fi

cd "$PROJECT_ROOT"

log_result "INFO" "Validating Employee Management Pipeline Health"

# Check Ansible inventory
echo -e "\n🔧 CHECKING ANSIBLE CONFIGURATION..."
if [[ -f "ansible/inventory" ]]; then
    log_result "PASS" "Ansible inventory file exists"
    
    # Validate inventory syntax
    if ansible-inventory -i ansible/inventory --list >/dev/null 2>&1; then
        log_result "PASS" "Ansible inventory syntax valid"
    else
        log_result "FAIL" "Ansible inventory syntax invalid"
    fi
    
    # Check connectivity to hosts
    if ansible all -i ansible/inventory -m ping --timeout=30 >/dev/null 2>&1; then
        log_result "PASS" "All Ansible hosts reachable"
    else
        log_result "WARN" "Some Ansible hosts may be unreachable"
    fi
else
    log_result "FAIL" "Ansible inventory file missing"
fi

# Check Jenkins files
echo -e "\n🏗️ CHECKING JENKINS CONFIGURATION..."
for jenkinsfile in "jenkins/backend.Jenkinsfile" "jenkins/frontend.Jenkinsfile"; do
    if [[ -f "$jenkinsfile" ]]; then
        log_result "PASS" "$jenkinsfile exists"
        
        # Basic syntax check (look for obvious issues)
        if grep -q "pipeline\s*{" "$jenkinsfile" && grep -q "stages\s*{" "$jenkinsfile"; then
            log_result "PASS" "$jenkinsfile has valid pipeline structure"
        else
            log_result "WARN" "$jenkinsfile may have structural issues"
        fi
    else
        log_result "FAIL" "$jenkinsfile missing"
    fi
done

# Check playbooks
echo -e "\n📋 CHECKING ANSIBLE PLAYBOOKS..."
for playbook in "ansible/roles-playbook.yml" "ansible/pre-deployment-check.yml" "ansible/error-recovery.yml"; do
    if [[ -f "$playbook" ]]; then
        log_result "PASS" "$playbook exists"
        
        # Validate YAML syntax
        if ansible-playbook --syntax-check "$playbook" >/dev/null 2>&1; then
            log_result "PASS" "$playbook syntax valid"
        else
            log_result "FAIL" "$playbook syntax invalid"
        fi
    else
        log_result "WARN" "$playbook missing (optional)"
    fi
done

# Check critical directories and files
echo -e "\n📁 CHECKING PROJECT STRUCTURE..."
for dir in "backend" "frontend" "ansible/roles"; do
    if [[ -d "$dir" ]]; then
        log_result "PASS" "$dir directory exists"
    else
        log_result "FAIL" "$dir directory missing"
    fi
done

for file in "backend/pom.xml" "frontend/package.json"; do
    if [[ -f "$file" ]]; then
        log_result "PASS" "$file exists"
    else
        log_result "FAIL" "$file missing"
    fi
done

# Check if services are accessible
echo -e "\n🌐 CHECKING LIVE SERVICES..."
# Check if load balancer is responding
if curl -s -f http://54.167.61.61 >/dev/null 2>&1; then
    log_result "PASS" "Load balancer (frontend) accessible"
else
    log_result "WARN" "Load balancer may not be accessible"
fi

# Check if API is responding
if curl -s -f http://54.167.61.61/api/employees >/dev/null 2>&1; then
    log_result "PASS" "API endpoints accessible"
else
    log_result "WARN" "API endpoints may not be accessible"
fi

# Check Git repository status
echo -e "\n📦 CHECKING REPOSITORY STATUS..."
if git status >/dev/null 2>&1; then
    log_result "PASS" "Git repository valid"
    
    # Check for uncommitted changes
    if [[ -z $(git status --porcelain) ]]; then
        log_result "PASS" "No uncommitted changes"
    else
        log_result "WARN" "Uncommitted changes present"
    fi
    
    # Check if we can access remote
    if git remote get-url origin >/dev/null 2>&1; then
        log_result "PASS" "Git remote configured"
    else
        log_result "WARN" "Git remote not configured"
    fi
else
    log_result "FAIL" "Not a valid Git repository"
fi

# Summary
echo -e "\n📊 VALIDATION SUMMARY"
echo "====================="
echo -e "✅ Passed: ${GREEN}$PASSED${NC}"
echo -e "❌ Failed: ${RED}$FAILED${NC}"  
echo -e "⚠️  Warnings: ${YELLOW}$WARNINGS${NC}"
echo -e "📋 Total checks: $((PASSED + FAILED + WARNINGS))"

if [[ $FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}🎉 Pipeline health validation completed successfully!${NC}"
    if [[ $WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}ℹ️  Some warnings found - review above for potential improvements${NC}"
    fi
    exit 0
else
    echo -e "\n${RED}❌ Pipeline health validation failed!${NC}"
    echo -e "${RED}Please fix the failed checks before running the pipeline${NC}"
    exit 1
fi