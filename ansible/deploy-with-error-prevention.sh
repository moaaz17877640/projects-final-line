#!/bin/bash
# Enhanced deployment script with error prevention and recovery

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/deployment.log"
INVENTORY_FILE="$SCRIPT_DIR/inventory"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Check prerequisites
check_prerequisites() {
    log "🔍 Checking prerequisites..."
    
    # Check if ansible is installed
    if ! command -v ansible-playbook &> /dev/null; then
        error "Ansible is not installed. Please install ansible first."
    fi
    
    # Check if inventory file exists
    if [ ! -f "$INVENTORY_FILE" ]; then
        error "Inventory file not found: $INVENTORY_FILE"
    fi
    
    # Check if SSH key exists
    SSH_KEY="../Key.pem"
    if [ ! -f "$SSH_KEY" ]; then
        error "SSH key not found: $SSH_KEY"
    fi
    
    # Ensure proper SSH key permissions
    chmod 400 "$SSH_KEY"
    
    success "Prerequisites check completed"
}

# Run pre-deployment validation
run_pre_validation() {
    log "🔍 Running pre-deployment validation..."
    
    if ansible-playbook -i "$INVENTORY_FILE" pre-deployment-check.yml -v; then
        success "Pre-deployment validation passed"
    else
        error "Pre-deployment validation failed. Please fix issues before proceeding."
    fi
}

# Main deployment with error handling
run_deployment() {
    log "🚀 Starting main deployment..."
    
    # Run with increased verbosity and error recovery
    if ansible-playbook -i "$INVENTORY_FILE" roles-playbook.yml -v \
        --timeout=300 \
        --ssh-extra-args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"; then
        success "Main deployment completed successfully"
    else
        warning "Deployment encountered issues. Attempting recovery..."
        
        # Attempt recovery by restarting services
        log "🔄 Attempting service recovery..."
        ansible all -i "$INVENTORY_FILE" -m service -a "name=employee-backend state=restarted" -b || true
        ansible loadbalancer -i "$INVENTORY_FILE" -m service -a "name=nginx state=reloaded" -b || true
        
        # Wait for services to stabilize
        sleep 30
        
        # Re-run deployment
        if ansible-playbook -i "$INVENTORY_FILE" roles-playbook.yml -v; then
            success "Recovery deployment completed successfully"
        else
            error "Deployment failed even after recovery attempt"
        fi
    fi
}

# Post-deployment verification
run_verification() {
    log "✅ Running post-deployment verification..."
    
    # Extract load balancer IP
    LB_IP=$(grep -A1 '\[loadbalancer\]' "$INVENTORY_FILE" | grep ansible_host | cut -d'=' -f2 | xargs)
    
    if [ -z "$LB_IP" ]; then
        error "Could not determine load balancer IP"
    fi
    
    log "Testing endpoints on $LB_IP..."
    
    # Test frontend
    if curl -f -s "http://$LB_IP/" > /dev/null; then
        success "✅ Frontend accessible"
    else
        error "❌ Frontend not accessible"
    fi
    
    # Test health endpoint
    HEALTH_RESPONSE=$(curl -s "http://$LB_IP/health" || echo "failed")
    if [ "$HEALTH_RESPONSE" = "healthy" ]; then
        success "✅ Health endpoint working"
    else
        error "❌ Health endpoint not working: $HEALTH_RESPONSE"
    fi
    
    # Test API endpoint
    if curl -f -s "http://$LB_IP/api/employees" | grep -q '"id":'; then
        EMPLOYEE_COUNT=$(curl -s "http://$LB_IP/api/employees" | grep -o '"id":' | wc -l)
        success "✅ API working ($EMPLOYEE_COUNT employees)"
    else
        error "❌ API not working"
    fi
}

# Generate deployment report
generate_report() {
    log "📊 Generating deployment report..."
    
    cat > "$SCRIPT_DIR/deployment-report.txt" << EOF
DEPLOYMENT REPORT
================
Date: $(date)
Status: SUCCESS

System Information:
- Load Balancer: $LB_IP
- Deployment Log: $LOG_FILE

Endpoints Verified:
✅ Frontend: http://$LB_IP/
✅ API: http://$LB_IP/api/employees
✅ Health: http://$LB_IP/health

For future deployments on new servers:
1. Ensure servers meet minimum requirements (2GB RAM, 5GB disk)
2. Run this script: ./deploy-with-error-prevention.sh
3. Monitor the deployment log for any issues

Error Prevention Measures Applied:
- Pre-deployment validation
- Service recovery mechanisms  
- Increased timeouts and retries
- Dynamic IP configuration
- Comprehensive health checks
EOF

    success "📊 Deployment report saved to: deployment-report.txt"
}

# Main execution
main() {
    log "🚀 Starting Enhanced Employee Management Deployment"
    log "📂 Working directory: $SCRIPT_DIR"
    
    check_prerequisites
    run_pre_validation
    run_deployment
    run_verification
    generate_report
    
    success "🎉 Deployment completed successfully! Check deployment-report.txt for details."
    
    echo ""
    echo -e "${GREEN}🌐 Your application is now accessible at:${NC}"
    echo -e "${BLUE}   Frontend: http://$LB_IP/${NC}"
    echo -e "${BLUE}   API: http://$LB_IP/api/employees${NC}"
    echo -e "${BLUE}   Health: http://$LB_IP/health${NC}"
}

# Run main function
main "$@"