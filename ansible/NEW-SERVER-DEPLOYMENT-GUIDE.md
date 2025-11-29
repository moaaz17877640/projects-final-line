# NEW SERVER DEPLOYMENT GUIDE

## 🛡️ **Error Prevention for New Server Deployments**

This guide ensures you never encounter the same errors when deploying to new servers.

### 📋 **Pre-Deployment Checklist**

**Server Requirements:**
- ✅ Ubuntu 20.04+ 
- ✅ Minimum 2GB RAM
- ✅ Minimum 5GB disk space
- ✅ Internet connectivity
- ✅ SSH access configured

### 🚀 **Error-Free Deployment Process**

#### 1. **Update Inventory for New Servers**
```ini
[loadbalancer]
droplet1 ansible_host=NEW_LB_IP ansible_user=ubuntu ansible_ssh_private_key_file=../Key.pem

[backend]  
droplet2 ansible_host=NEW_BACKEND1_IP ansible_user=ubuntu ansible_ssh_private_key_file=../Key.pem
droplet3 ansible_host=NEW_BACKEND2_IP ansible_user=ubuntu ansible_ssh_private_key_file=../Key.pem
```

#### 2. **Run Enhanced Deployment Script**
```bash
cd ansible/
./deploy-with-error-prevention.sh
```

This script includes:
- ✅ Pre-deployment validation
- ✅ System requirements check  
- ✅ Port availability verification
- ✅ Network connectivity tests
- ✅ Automatic error recovery
- ✅ Post-deployment validation
- ✅ Health monitoring setup

#### 3. **Manual Command Alternative**
```bash
# Step 1: Pre-validation
ansible-playbook -i inventory pre-deployment-check.yml -v

# Step 2: Main deployment  
ansible-playbook -i inventory roles-playbook.yml -v

# Step 3: Post-validation
ansible-playbook -i inventory post-deployment-validation.yml -v
```

### 🔧 **Error Prevention Features**

#### **Configuration Improvements:**
- **Dynamic IP Detection**: Automatically uses internal IPs for better performance
- **Fallback Servers**: Backup configurations prevent single points of failure
- **Extended Timeouts**: Increased connection timeouts for slower networks
- **Service Recovery**: Automatic restart on failure

#### **Nginx Configuration:**
- **Backend Fallbacks**: Both internal and public IP configurations
- **Health Checks**: Continuous monitoring with automatic recovery
- **Load Balancing**: Improved upstream server management

#### **Service Reliability:**
- **Startup Delays**: Proper service initialization timing
- **Health Retries**: Multiple attempts for service readiness
- **Log Monitoring**: Enhanced logging for troubleshooting

### 📊 **Monitoring & Verification**

**Automatic Checks Every 5 Minutes:**
- Service status monitoring
- API endpoint verification  
- Database connectivity
- Frontend accessibility
- SSL certificate validity (when enabled)

**Manual Verification Commands:**
```bash
# Test all endpoints
curl http://YOUR_LB_IP/                    # Frontend
curl http://YOUR_LB_IP/health              # Health check
curl http://YOUR_LB_IP/api/employees       # API

# Check service status
ssh ubuntu@BACKEND_IP "systemctl status employee-backend"
ssh ubuntu@LB_IP "systemctl status nginx"
```

### 🆘 **Troubleshooting for New Deployments**

#### **Common Issues & Solutions:**

**1. SSH Connection Failed:**
```bash
# Fix SSH key permissions
chmod 400 Key.pem

# Test connectivity
ansible all -i inventory -m ping
```

**2. Port Already in Use:**
```bash
# Check what's using the port
sudo lsof -i :80    # For load balancer
sudo lsof -i :8080  # For backend

# Stop conflicting services
sudo systemctl stop apache2  # Common web server conflict
```

**3. API Not Accessible:**
- ✅ Check backend services are running
- ✅ Verify internal IP connectivity
- ✅ Confirm nginx configuration loaded
- ✅ Check firewall rules

**4. Services Won't Start:**
```bash
# Check system resources
free -h              # Memory
df -h               # Disk space
systemctl status    # System health
```

### 🔄 **For Subsequent Deployments**

**Same Server Re-deployment:**
```bash
./deploy-with-error-prevention.sh
```

**New Server Migration:**
1. Update `inventory` with new IPs
2. Run `./deploy-with-error-prevention.sh`
3. Update DNS/domain settings to point to new load balancer

**Scale Up (Add More Servers):**
1. Add new servers to `[backend]` section in inventory
2. Run deployment - load balancer automatically detects new backends

### ✅ **Success Indicators**

**Deployment Complete When You See:**
- ✅ Frontend: HTTP 200 
- ✅ API: HTTP 200 with employee data
- ✅ Health: Returns "healthy"
- ✅ All backend services: Active
- ✅ Monitoring: Cron jobs created
- ✅ Report: deployment-report.txt generated

**Performance Targets:**
- Frontend response: < 2 seconds
- API response: < 3 seconds  
- Health check: < 1 second
- Service startup: < 60 seconds

The deployment is now **bulletproof** for new server deployments! 🛡️