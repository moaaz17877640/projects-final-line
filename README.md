# Employee Management App - Complete Jenkins CI/CD Deployment Guide

This guide provides step-by-step instructions to set up the complete CI/CD pipeline for deploying the Employee Management Application to DigitalOcean droplets using Jenkins and Ansible.

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Infrastructure Setup](#infrastructure-setup)
4. [Jenkins Server Setup](#jenkins-server-setup)
5. [Jenkins Credentials Configuration](#jenkins-credentials-configuration)
6. [Pipeline Configuration](#pipeline-configuration)
7. [Running the Pipelines](#running-the-pipelines)
8. [Verification & Troubleshooting](#verification--troubleshooting)

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        JENKINS SERVER                           │
│                    (CI/CD Orchestration)                        │
│  ┌─────────────────┐         ┌─────────────────┐               │
│  │ Frontend        │         │ Backend         │               │
│  │ Pipeline        │         │ Pipeline        │               │
│  └────────┬────────┘         └────────┬────────┘               │
└───────────┼──────────────────────────┼─────────────────────────┘
            │                          │
            │     Ansible Deploy       │
            ▼                          ▼
┌───────────────────┐    ┌───────────────────┐    ┌───────────────────┐
│     DROPLET 1     │    │     DROPLET 2     │    │     DROPLET 3     │
│   Load Balancer   │    │  Backend Server 1 │    │  Backend Server 2 │
│   + Frontend      │    │   (Spring Boot)   │    │   (Spring Boot)   │
│     (Nginx)       │    │     + MySQL       │    │     + MySQL       │
│                   │    │                   │    │                   │
│  165.232.112.136  │    │   138.68.90.46    │    │  206.189.61.18    │
└─────────┬─────────┘    └─────────┬─────────┘    └─────────┬─────────┘
          │                        │                        │
          │    ┌───────────────────┴────────────────────┐  │
          └────►       Upstream Backend Pool            ◄──┘
               │   (Round-robin load balancing)         │
               └────────────────────────────────────────┘
```

### Components

| Component | Server | IP Address | Port | Description |
|-----------|--------|------------|------|-------------|
| **Nginx Load Balancer** | Droplet 1 | 165.232.112.136 | 80 | Serves React frontend, proxies /api to backends |
| **React Frontend** | Droplet 1 | 165.232.112.136 | 80 | Static files served by Nginx |
| **Spring Boot Backend #1** | Droplet 2 | 138.68.90.46 | 8080 | Backend API + MySQL |
| **Spring Boot Backend #2** | Droplet 3 | 206.189.61.18 | 8080 | Backend API + MySQL |

---

## ✅ Prerequisites

### On Your Local Machine
- Git installed
- SSH client

### On Jenkins Server
- **Jenkins** 2.x or later
- **Java 17** (OpenJDK)
- **Maven 3.x**
- **Node.js 18.x** and npm
- **Ansible** 2.9+
- **sshpass** (for password-based SSH)

### DigitalOcean Droplets
- 3 Ubuntu 22.04/24.04 droplets
- Root access with SSH passwords
- Ports open: 22 (SSH), 80 (HTTP), 8080 (Backend)

---

## 🖥️ Infrastructure Setup

### Step 1: Create DigitalOcean Droplets

Create 3 droplets with the following configuration:
- **Image**: Ubuntu 22.04 or 24.04 LTS
- **Size**: Basic - 1GB RAM / 1 CPU (minimum)
- **Region**: Same region for all (e.g., NYC1)
- **Authentication**: Password (note down the passwords)

### Step 2: Note Down Server Details

After creation, record:
```
Droplet 1 (Load Balancer): 165.232.112.136 - Password: <your-lb-password>
Droplet 2 (Backend 1):     138.68.90.46    - Password: <your-backend-password>
Droplet 3 (Backend 2):     206.189.61.18   - Password: <your-backend-password>
```

### Step 3: Test SSH Connectivity

```bash
# Test connection to each droplet
ssh root@165.232.112.136
ssh root@138.68.90.46
ssh root@206.189.61.18
```

---

## 🔧 Jenkins Server Setup

### Step 1: Install Required Tools

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Java 17
sudo apt install -y openjdk-17-jdk
java -version

# Install Maven
sudo apt install -y maven
mvn -version

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs
node --version
npm --version

# Install Ansible
sudo apt install -y ansible
ansible --version

# Install sshpass (for password-based SSH)
sudo apt install -y sshpass
which sshpass
```

### Step 2: Install Jenkins

```bash
# Add Jenkins repository
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Install Jenkins
sudo apt update
sudo apt install -y jenkins

# Start Jenkins
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### Step 3: Complete Jenkins Setup

1. Open Jenkins in browser: `http://<jenkins-server-ip>:8080`
2. Enter the initial admin password
3. Install suggested plugins
4. Create admin user
5. Configure Jenkins URL

### Step 4: Install Required Jenkins Plugins

Go to **Manage Jenkins** → **Plugins** → **Available plugins**

Install:
- Git
- Pipeline
- Pipeline: Stage View
- Ansible
- SSH Agent
- Credentials Binding

---

## 🔐 Jenkins Credentials Configuration

### Step 1: Navigate to Credentials

1. Go to **Manage Jenkins** → **Credentials**
2. Click **System** → **Global credentials (unrestricted)**
3. Click **Add Credentials**

### Step 2: Create Load Balancer Credential

| Field | Value |
|-------|-------|
| **Kind** | Secret text |
| **Scope** | Global |
| **Secret** | `<your-lb-password>` (e.g., `4Dun8YzW01DU`) |
| **ID** | `LOADBALANCER_SSH_PASSWORD` |
| **Description** | SSH password for Load Balancer (Droplet 1) |

Click **Create**

### Step 3: Create Backend Servers Credential

| Field | Value |
|-------|-------|
| **Kind** | Secret text |
| **Scope** | Global |
| **Secret** | `<your-backend-password>` (e.g., `SehFaNG7dOxUnr`) |
| **ID** | `BACKEND_SSH_PASSWORD` |
| **Description** | SSH password for Backend servers (Droplet 2 & 3) |

Click **Create**

### Step 4: Verify Credentials

You should now have 2 credentials:
- `LOADBALANCER_SSH_PASSWORD`
- `BACKEND_SSH_PASSWORD`

---

## 📦 Pipeline Configuration

### Step 1: Create Frontend Pipeline

1. Click **New Item**
2. Enter name: `employee-management-frontend`
3. Select **Pipeline**
4. Click **OK**

Configure:
- **Description**: Frontend CI/CD Pipeline for Employee Management App
- **Pipeline Definition**: Pipeline script from SCM
- **SCM**: Git
- **Repository URL**: `https://github.com/moaaz17877640/Employee-Management-Fullstack-App.git`
- **Branch**: `*/master`
- **Script Path**: `jenkins/frontend.Jenkinsfile`

Click **Save**

### Step 2: Create Backend Pipeline

1. Click **New Item**
2. Enter name: `employee-management-backend`
3. Select **Pipeline**
4. Click **OK**

Configure:
- **Description**: Backend CI/CD Pipeline for Employee Management App
- **Pipeline Definition**: Pipeline script from SCM
- **SCM**: Git
- **Repository URL**: `https://github.com/moaaz17877640/Employee-Management-Fullstack-App.git`
- **Branch**: `*/master`
- **Script Path**: `jenkins/backend.Jenkinsfile`

Click **Save**

---

## 🚀 Running the Pipelines

### Deployment Order

**Important**: Run pipelines in this order:

1. **Backend Pipeline First** - Deploys Spring Boot to Droplet 2 & 3
2. **Frontend Pipeline Second** - Deploys React + Nginx to Droplet 1

### Run Backend Pipeline

1. Go to `employee-management-backend`
2. Click **Build Now**
3. Monitor progress in **Console Output**

Expected stages:
```
✅ Checkout Repository
✅ Build & Migrate DB
✅ Run Tests
✅ Package JAR
✅ Deploy to Backend Servers (Rolling deployment)
✅ Update Load Balancer
✅ Final Validation
```

### Run Frontend Pipeline

1. Go to `employee-management-frontend`
2. Click **Build Now**
3. Monitor progress in **Console Output**

Expected stages:
```
✅ Checkout Code
✅ Install Dependencies
✅ Build React Production Bundle
✅ Deploy to Load Balancer
✅ Final Validation
```

---

## ✔️ Verification & Troubleshooting

### Verify Deployment

After both pipelines complete successfully:

```bash
# Test Frontend
curl -s http://165.232.112.136/ | head -5

# Test API through Load Balancer
curl -s http://165.232.112.136/api/employees | head -100

# Test Backend directly
curl -s http://138.68.90.46:8080/api/employees | head -50
curl -s http://206.189.61.18:8080/api/employees | head -50
```

### Access the Application

Open in browser: **http://165.232.112.136**

### Common Issues & Solutions

#### Issue: "Permission denied" during Ansible

**Solution**: Verify credentials are correctly configured in Jenkins:
```bash
# Test from Jenkins server
sshpass -p 'your-password' ssh -o StrictHostKeyChecking=no root@165.232.112.136 'echo connected'
```

#### Issue: "sshpass not found"

**Solution**: Install sshpass on Jenkins server:
```bash
sudo apt install -y sshpass
```

#### Issue: API returns 404

**Solution**: Reload Nginx configuration:
```bash
ssh root@165.232.112.136 'nginx -t && systemctl reload nginx'
```

#### Issue: Backend not responding

**Solution**: Check service status:
```bash
ssh root@138.68.90.46 'systemctl status employee-backend'
ssh root@138.68.90.46 'journalctl -u employee-backend -n 50'
```

#### Issue: Frontend build timeout

The frontend pipeline has a 45-minute timeout. If it times out:
- Check Node.js memory: `export NODE_OPTIONS="--max-old-space-size=4096"`
- The frontend role now copies pre-built files instead of building on the server

---

## 📁 Project Structure

```
Employee-Management-Fullstack-App/
├── ansible/
│   ├── inventory                 # Server IPs (no passwords)
│   ├── roles-playbook.yml        # Main playbook
│   └── roles/
│       ├── frontend/             # React deployment role
│       ├── backend/              # Spring Boot deployment role
│       └── loadbalancer/         # Nginx configuration role
├── jenkins/
│   ├── frontend.Jenkinsfile      # Frontend CI/CD pipeline
│   └── backend.Jenkinsfile       # Backend CI/CD pipeline
├── frontend/                     # React application
├── backend/                      # Spring Boot application
└── README.md
```

---

## 🔒 Security Notes

1. **Passwords are stored in Jenkins credentials**, not in the repository
2. The `ansible/inventory` file contains only server IPs, not passwords
3. Passwords are injected at runtime via `--extra-vars`
4. Consider using SSH keys instead of passwords for production

---

## 📞 Support

For issues or questions:
1. Check Jenkins Console Output for detailed error messages
2. Review Ansible logs for deployment issues
3. Check service logs on the droplets

---

## 📝 Quick Reference

### Jenkins Credentials Required

| Credential ID | Description |
|---------------|-------------|
| `LOADBALANCER_SSH_PASSWORD` | SSH password for Droplet 1 (165.232.112.136) |
| `BACKEND_SSH_PASSWORD` | SSH password for Droplet 2 & 3 |

### Server Access

```bash
# Load Balancer
ssh root@165.232.112.136

# Backend 1
ssh root@138.68.90.46

# Backend 2
ssh root@206.189.61.18
```

### Useful Commands

```bash
# Check Nginx status
systemctl status nginx

# Check Backend status
systemctl status employee-backend

# View Backend logs
journalctl -u employee-backend -f

# Reload Nginx
systemctl reload nginx

# Restart Backend
systemctl restart employee-backend
```
