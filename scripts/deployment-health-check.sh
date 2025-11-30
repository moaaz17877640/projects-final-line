#!/bin/bash
# Deployment Health Check Script for Employee Management System
# This script ensures both backend and frontend are properly deployed and accessible

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
LOAD_BALANCER_IP="23.22.172.211"
BACKEND_SERVERS=("52.201.244.231" "54.91.101.177")
BACKEND_PORT="8080"
FRONTEND_PORT="80"
MAX_RETRIES=5
RETRY_DELAY=10

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to test API endpoint with retries
test_api_endpoint() {
    local url="$1"
    local description="$2"
    local max_retries="${3:-$MAX_RETRIES}"
    
    log_info "Testing $description: $url"
    
    for ((i=1; i<=max_retries; i++)); do
        if curl -f -s -o /dev/null -w "%{http_code}" --max-time 30 "$url" | grep -q "200"; then
            log_success "$description is responding (attempt $i/$max_retries)"
            return 0
        else
            log_warning "$description not responding (attempt $i/$max_retries)"
            if [ $i -lt $max_retries ]; then
                log_info "Waiting ${RETRY_DELAY}s before retry..."
                sleep $RETRY_DELAY
            fi
        fi
    done
    
    log_error "$description failed to respond after $max_retries attempts"
    return 1
}

# Function to check service status via SSH
check_service_status() {
    local server="$1"
    local service="$2"
    
    log_info "Checking $service status on $server"
    
    if ssh -i "$PROJECT_ROOT/Key.pem" -o ConnectTimeout=10 ubuntu@"$server" "sudo systemctl is-active $service" > /dev/null 2>&1; then
        log_success "$service is active on $server"
        return 0
    else
        log_error "$service is not active on $server"
        # Try to get service status for debugging
        ssh -i "$PROJECT_ROOT/Key.pem" -o ConnectTimeout=10 ubuntu@"$server" "sudo systemctl status $service --no-pager -n 5" || true
        return 1
    fi
}

# Function to restart service if needed
restart_service_if_needed() {
    local server="$1"
    local service="$2"
    
    if ! check_service_status "$server" "$service"; then
        log_warning "Attempting to restart $service on $server"
        if ssh -i "$PROJECT_ROOT/Key.pem" -o ConnectTimeout=30 ubuntu@"$server" "sudo systemctl restart $service"; then
            log_info "Waiting for $service to start..."
            sleep 30
            if check_service_status "$server" "$service"; then
                log_success "$service restarted successfully on $server"
                return 0
            fi
        fi
        log_error "Failed to restart $service on $server"
        return 1
    fi
    return 0
}

# Main health check function
run_health_check() {
    local failed_checks=0
    
    log_info "Starting comprehensive deployment health check..."
    echo
    
    # 1. Check SSH key permissions
    log_info "Checking SSH key permissions..."
    if [ -f "$PROJECT_ROOT/Key.pem" ]; then
        chmod 600 "$PROJECT_ROOT/Key.pem"
        log_success "SSH key permissions set correctly"
    else
        log_error "SSH key not found at $PROJECT_ROOT/Key.pem"
        ((failed_checks++))
    fi
    echo
    
    # 2. Check backend services
    log_info "Checking backend services..."
    for server in "${BACKEND_SERVERS[@]}"; do
        if ! restart_service_if_needed "$server" "employee-backend"; then
            ((failed_checks++))
        fi
    done
    echo
    
    # 3. Test direct backend API endpoints
    log_info "Testing direct backend API endpoints..."
    for server in "${BACKEND_SERVERS[@]}"; do
        if ! test_api_endpoint "http://$server:$BACKEND_PORT/api/employees" "Backend API on $server" 3; then
            ((failed_checks++))
        fi
    done
    echo
    
    # 4. Check Nginx service on load balancer
    log_info "Checking load balancer service..."
    if ! check_service_status "$LOAD_BALANCER_IP" "nginx"; then
        log_warning "Attempting to restart nginx on load balancer"
        ssh -i "$PROJECT_ROOT/Key.pem" ubuntu@"$LOAD_BALANCER_IP" "sudo systemctl restart nginx" || true
        sleep 10
    fi
    echo
    
    # 5. Test frontend through load balancer
    log_info "Testing frontend availability..."
    if ! test_api_endpoint "http://$LOAD_BALANCER_IP/" "Frontend" 3; then
        ((failed_checks++))
    fi
    echo
    
    # 6. Test API routing through load balancer
    log_info "Testing API routing through load balancer..."
    if ! test_api_endpoint "http://$LOAD_BALANCER_IP/api/employees" "Load Balancer API" 5; then
        ((failed_checks++))
        
        # Additional debugging for load balancer
        log_warning "API routing failed - checking load balancer configuration"
        ssh -i "$PROJECT_ROOT/Key.pem" ubuntu@"$LOAD_BALANCER_IP" "sudo nginx -t" || true
        ssh -i "$PROJECT_ROOT/Key.pem" ubuntu@"$LOAD_BALANCER_IP" "sudo tail -10 /var/log/nginx/error.log" || true
    fi
    echo
    
    # 7. Summary
    if [ $failed_checks -eq 0 ]; then
        log_success "🎉 All health checks passed! System is fully operational."
        log_info "Frontend: http://$LOAD_BALANCER_IP/"
        log_info "API: http://$LOAD_BALANCER_IP/api/employees"
        return 0
    else
        log_error "⚠️ $failed_checks health check(s) failed. System may not be fully operational."
        return 1
    fi
}

# Command line interface
case "${1:-check}" in
    "check"|"")
        run_health_check
        ;;
    "backend")
        log_info "Checking backend services only..."
        for server in "${BACKEND_SERVERS[@]}"; do
            restart_service_if_needed "$server" "employee-backend"
            test_api_endpoint "http://$server:$BACKEND_PORT/api/employees" "Backend API on $server"
        done
        ;;
    "frontend")
        log_info "Checking frontend only..."
        test_api_endpoint "http://$LOAD_BALANCER_IP/" "Frontend"
        ;;
    "api")
        log_info "Checking API routing only..."
        test_api_endpoint "http://$LOAD_BALANCER_IP/api/employees" "Load Balancer API"
        ;;
    "help")
        echo "Usage: $0 [check|backend|frontend|api|help]"
        echo "  check    - Run full health check (default)"
        echo "  backend  - Check backend services only"
        echo "  frontend - Check frontend only"
        echo "  api      - Check API routing only" 
        echo "  help     - Show this help message"
        ;;
    *)
        log_error "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac