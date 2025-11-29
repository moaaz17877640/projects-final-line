# Jenkins CI/CD Setup Guide for Employee Management App

## 🚀 **Overview**

This guide provides complete setup instructions for Jenkins CI/CD pipelines that integrate with the enhanced Ansible deployment system for zero-downtime deployments.

## 📋 **Prerequisites**

### **Server Requirements:**
- Jenkins Server with minimum 4GB RAM
- Docker installed (for optional container builds)
- Ansible 2.9+ installed
- Node.js 18.x for frontend builds
- Maven 3.8+ for backend builds
- SSH access to deployment servers

### **Required Jenkins Plugins:**
```bash
# Essential plugins for the pipelines
- Pipeline
- Git
- NodeJS
- Maven Integration  
- Ansible
- Docker Pipeline (optional)
- Blue Ocean (recommended for UI)
```

## 🔧 **Jenkins Configuration**

### **1. Global Tool Configuration**

#### **Maven Configuration:**
```
Name: Maven-3.8
Version: 3.8.6
Install automatically: ✅
```

#### **NodeJS Configuration:**
```
Name: NodeJS-18
Version: 18.20.8
Install automatically: ✅
Global npm packages: npm@latest
```

#### **Git Configuration:**
```
Name: Default
Path to Git executable: /usr/bin/git
```

### **2. System Configuration**

#### **SSH Key Setup:**
```bash
# Add the deployment SSH key to Jenkins credentials
Credentials → Global → Add Credentials
Kind: SSH Username with private key
ID: deployment-ssh-key
Username: ubuntu
Private Key: [Paste contents of Key.pem]
```

#### **Environment Variables:**
```bash
# In Jenkins → Manage Jenkins → Configure System → Global Properties
ANSIBLE_HOST_KEY_CHECKING=False
DEPLOYMENT_ENV=production
```

## 📦 **Pipeline Setup**

### **Backend CI/CD Pipeline**

#### **Create New Pipeline Job:**
1. **New Item** → **Pipeline** → Name: `employee-management-backend`
2. **Pipeline Configuration:**
   ```groovy
   Pipeline script from SCM
   SCM: Git
   Repository URL: https://github.com/hoangsonww/Employee-Management-Fullstack-App.git
   Branch: master
   Script Path: jenkins/backend.Jenkinsfile
   ```

#### **Build Triggers:**
```
✅ Poll SCM: H/5 * * * * (every 5 minutes)
✅ GitHub hook trigger for GITScm polling
```

### **Frontend CI/CD Pipeline**

#### **Create New Pipeline Job:**
1. **New Item** → **Pipeline** → Name: `employee-management-frontend`
2. **Pipeline Configuration:**
   ```groovy
   Pipeline script from SCM
   SCM: Git
   Repository URL: https://github.com/hoangsonww/Employee-Management-Fullstack-App.git
   Branch: master
   Script Path: jenkins/frontend.Jenkinsfile
   ```

#### **Build Triggers:**
```
✅ Poll SCM: H/5 * * * * (every 5 minutes)
✅ GitHub hook trigger for GITScm polling
```

## 🔄 **Pipeline Features**

### **Backend Pipeline Capabilities:**

#### **Zero-Downtime Rolling Deployment:**
- ✅ Deploys to backend servers one at a time
- ✅ Waits for health checks before proceeding
- ✅ Automatic rollback on failure
- ✅ Database migration support

#### **Pipeline Stages:**
1. **Checkout Code** - Pull latest from Git
2. **Build with Maven** - Compile and test
3. **Run Tests** - Unit and integration tests
4. **Package JAR** - Create deployable artifact
5. **Setup Ansible** - Validate deployment environment
6. **Optional Docker Build** - Create container image
7. **Rolling Deployment** - Zero-downtime deployment to backends
8. **Post-deployment Validation** - Comprehensive health checks

### **Frontend Pipeline Capabilities:**

#### **Optimized React Deployment:**
- ✅ Production build optimization
- ✅ Static file caching configuration
- ✅ CDN-ready asset management
- ✅ Zero-downtime deployment to load balancer

#### **Pipeline Stages:**
1. **Checkout Code** - Pull latest from Git
2. **Install Dependencies** - npm install with caching
3. **Build Production Bundle** - Optimized React build
4. **Deploy to Load Balancer** - Update frontend files with zero downtime
5. **Validation** - Verify deployment success

## 🛡️ **Error Prevention & Recovery**

### **Automatic Validation Checks:**
- ✅ Pre-deployment system validation
- ✅ Service health verification
- ✅ Database connectivity tests
- ✅ Port availability checks
- ✅ Network connectivity validation

### **Rollback Mechanisms:**
```groovy
// Automatic rollback on deployment failure
post {
    failure {
        script {
            sh """
                cd ${ANSIBLE_PLAYBOOK_DIR}
                echo "🔄 Deployment failed, initiating rollback..."
                ansible-playbook -i inventory rollback-deployment.yml -v
            """
        }
    }
}
```

## 📊 **Monitoring & Notifications**

### **Slack Integration (Optional):**
```groovy
post {
    success {
        slackSend(
            color: 'good',
            message: "✅ Deployment completed successfully: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
        )
    }
    failure {
        slackSend(
            color: 'danger',
            message: "❌ Deployment failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
        )
    }
}
```

### **Email Notifications:**
```
Post-build Actions → Email Notification
Recipients: admin@yourcompany.com
Send for: Failure, Unstable, Fixed
```

## 🚀 **Deployment Process**

### **Backend Deployment Flow:**
```bash
1. Code Push → GitHub
2. Jenkins detects change (webhook/polling)
3. Build & Test backend
4. Package JAR file
5. Pre-deployment validation
6. Rolling deployment:
   - Deploy to Server 1
   - Health check Server 1
   - Deploy to Server 2
   - Health check Server 2
7. Post-deployment validation
8. Notifications sent
```

### **Frontend Deployment Flow:**
```bash
1. Code Push → GitHub
2. Jenkins detects change
3. Install npm dependencies
4. Build production React app
5. Pre-deployment validation
6. Deploy to Load Balancer:
   - Backup current files
   - Upload new build
   - Update nginx config
   - Reload nginx (zero downtime)
7. Validation & notifications
```

## 🔍 **Testing the Setup**

### **Manual Test Commands:**
```bash
# Test backend pipeline
curl -X POST http://jenkins-server:8080/job/employee-management-backend/build

# Test frontend pipeline  
curl -X POST http://jenkins-server:8080/job/employee-management-frontend/build

# Check deployment status
curl http://YOUR_LB_IP/health
curl http://YOUR_LB_IP/api/employees
```

### **Validation Checklist:**
- ✅ Pipeline triggers on code push
- ✅ Backend builds and tests pass
- ✅ Frontend builds successfully  
- ✅ Zero-downtime deployment works
- ✅ Health checks pass
- ✅ Rollback works on failure
- ✅ Notifications are sent

## 🆘 **Troubleshooting**

### **Common Issues:**

#### **SSH Connection Failed:**
```bash
# Fix in Jenkins credentials
Jenkins → Credentials → deployment-ssh-key
Verify private key format and permissions
```

#### **Ansible Playbook Failed:**
```bash
# Check Ansible inventory
cd /path/to/ansible
ansible all -i inventory -m ping
```

#### **Build Fails:**
```bash
# Check tool installations
jenkins-cli.sh -s http://localhost:8080 list-plugins | grep -E "(maven|nodejs|ansible)"
```

#### **Deployment Timeout:**
```bash
# Increase timeout in pipeline
timeout(time: 30, unit: 'MINUTES')
```

## 🎯 **Best Practices**

### **Pipeline Optimization:**
- ✅ Use parallel stages where possible
- ✅ Cache dependencies (Maven, npm)
- ✅ Minimize artifact size
- ✅ Implement proper logging

### **Security:**
- ✅ Use Jenkins credentials manager
- ✅ Limit pipeline permissions
- ✅ Secure SSH keys
- ✅ Enable CSRF protection

### **Monitoring:**
- ✅ Set up build notifications
- ✅ Monitor deployment metrics
- ✅ Track build success rates
- ✅ Log aggregation setup

## 📈 **Performance Metrics**

### **Target Performance:**
- **Backend Build Time**: < 5 minutes
- **Frontend Build Time**: < 3 minutes  
- **Deployment Time**: < 2 minutes
- **Zero-Downtime**: < 30 seconds
- **Health Check Response**: < 5 seconds

The CI/CD system is now fully integrated with your enhanced Ansible deployment system for reliable, zero-downtime deployments! 🚀