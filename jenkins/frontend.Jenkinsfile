#!/usr/bin/env groovy

/**
 * Frontend CI/CD Pipeline for Employee Management Application
 * 
 * Project: Employee Management Fullstack App – DevOps CI/CD & Deployment
 * Tech Stack: React (Frontend)
 * DevOps Tools: Ansible, Jenkins, Nginx
 * 
 * Pipeline Stages (as per project requirements):
 * 1. Checkout code
 * 2. Install dependencies
 * 3. Build React production bundle
 * 4. Deploy build files to Load Balancer server using Ansible
 * 
 * Required Jenkins Credentials:
 * - LOADBALANCER_SSH_PASSWORD: SSH password for droplet1 (Load Balancer)
 */

pipeline {
    agent any
    
    environment {
        // Application Configuration
        APP_NAME = 'employee-management-frontend'
        APP_VERSION = "${env.BUILD_NUMBER}"
        GIT_REPO = 'https://github.com/moaaz17877640/Employee-Management-Fullstack-App.git'
        
        // Node.js Configuration
        NODE_VERSION = '18'
        
        // React Environment Variables
        REACT_APP_API_URL = '/api'
        REACT_APP_ENVIRONMENT = 'production'
        
        // Ansible Configuration
        ANSIBLE_INVENTORY = 'ansible/inventory'
        ANSIBLE_HOST_KEY_CHECKING = 'False'
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 45, unit: 'MINUTES')
        timestamps()
    }
    
    stages {
        /**
         * Stage 1: Checkout Code
         */
        stage('Checkout Code') {
            steps {
                echo "🔄 Checking out repository from ${env.GIT_REPO}"
                deleteDir()
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/master']],
                    extensions: [
                        [$class: 'CloneOption', timeout: 60, shallow: true, depth: 1],
                        [$class: 'CheckoutOption', timeout: 60]
                    ],
                    userRemoteConfigs: [[url: env.GIT_REPO]]
                ])
                sh 'ls -la'
            }
        }
        
        /**
         * Stage 2: Install Dependencies
         */
        stage('Install Dependencies') {
            steps {
                dir('frontend') {
                    echo "📦 Installing npm dependencies"
                    sh '''
                        # Show Node.js and npm versions
                        node --version
                        npm --version
                        
                        # Clean install - remove old dependencies
                        rm -rf node_modules package-lock.json
                        
                        # Clear npm cache to avoid stale dependencies
                        npm cache clean --force
                        
                        # Install ajv first to resolve dependency conflict
                        npm install ajv@8.12.0 --legacy-peer-deps
                        
                        # Install all dependencies
                        npm install --legacy-peer-deps
                        
                        # Verify ajv installation
                        ls -la node_modules/ajv/
                    '''
                }
            }
        }
        
        /**
         * Stage 3: Build React Production Bundle
         */
        stage('Build React Production Bundle') {
            steps {
                dir('frontend') {
                    echo "🏗️ Building React application for production"
                    
                    // Create production environment file
                    writeFile(
                        file: '.env.production',
                        text: """
REACT_APP_API_URL=${env.REACT_APP_API_URL}
REACT_APP_ENVIRONMENT=${env.REACT_APP_ENVIRONMENT}
REACT_APP_VERSION=${env.APP_VERSION}
GENERATE_SOURCEMAP=false
                        """.stripIndent().trim()
                    )
                    
                    sh '''
                        # Build production bundle
                        npm run build
                        
                        # Verify build output
                        ls -la build/
                    '''
                    
                    // Archive build artifacts
                    script {
                        sh "tar -czf frontend-build-${env.BUILD_NUMBER}.tar.gz -C build ."
                        archiveArtifacts(
                            artifacts: "frontend-build-${env.BUILD_NUMBER}.tar.gz",
                            fingerprint: true
                        )
                    }
                }
            }
        }
        
        /**
         * Stage 4: Deploy to Load Balancer Server using Ansible
         * Deploy React build files to Droplet 1 (Load Balancer + Frontend)
         */
        stage('Deploy to Load Balancer') {
            steps {
                echo "🚀 Deploying React build to Load Balancer server (Droplet 1)"
                
                // Verify sshpass is installed (should be pre-installed on Jenkins server)
                sh "which sshpass && echo '✅ sshpass is available'"
                
                // Use Jenkins credentials for SSH password
                withCredentials([string(credentialsId: 'LOADBALANCER_SSH_PASSWORD', variable: 'LB_PASSWORD')]) {
                    script {
                        // Pre-deployment: Verify server connectivity
                        echo "🔍 Verifying server connectivity..."
                        sh '''
                            cd ansible
                            ansible loadbalancer -i inventory -m ping --timeout=30 \
                                --extra-vars "ansible_password=${LB_PASSWORD}"
                        '''
                        
                        // Deploy frontend using Ansible playbook
                        echo "📦 Deploying frontend build files..."
                        sh """
                            cd ansible
                            ansible-playbook -i inventory roles-playbook.yml \
                                --limit loadbalancer \
                                --extra-vars "ansible_password=\${LB_PASSWORD}" \
                                --extra-vars "app_version=${env.APP_VERSION}" \
                                --extra-vars "build_number=${env.BUILD_NUMBER}" \
                                -v
                        """
                        
                        // Wait for Nginx to reload
                        sleep(time: 10, unit: 'SECONDS')
                        
                        // Verify frontend is served correctly
                        echo "🔍 Verifying frontend deployment..."
                        sh '''
                            cd ansible
                            ansible loadbalancer -i inventory -m shell \
                                -a "curl -sf http://localhost/ | head -20" \
                                --extra-vars "ansible_password=${LB_PASSWORD}" \
                                --timeout=60
                        '''
                        
                        // Verify API routing through Nginx (optional - backend may not be deployed yet)
                        echo "🔗 Checking API routing (optional - backend may not be deployed)..."
                        sh '''
                            cd ansible
                            ansible loadbalancer -i inventory -m shell \
                                -a "curl -sf --max-time 5 http://localhost/api/employees || echo 'API not available yet - run backend pipeline first'" \
                                --extra-vars "ansible_password=${LB_PASSWORD}" \
                                --timeout=30
                        '''
                    }
                }
            }
        }
        
        /**
         * Final Validation
         */
        stage('Final Validation') {
            steps {
                echo "🏥 Running final validation checks"
                
                withCredentials([string(credentialsId: 'LOADBALANCER_SSH_PASSWORD', variable: 'LB_PASSWORD')]) {
                    sh '''
                        cd ansible
                        
                        echo "=== Nginx Status ==="
                        ansible loadbalancer -i inventory -m shell \
                            -a "nginx -t && systemctl is-active nginx" \
                            --extra-vars "ansible_password=${LB_PASSWORD}"
                        
                        echo "=== Frontend Served ==="
                        ansible loadbalancer -i inventory -m shell \
                            -a "curl -sf -o /dev/null -w '%{http_code}' http://localhost/" \
                            --extra-vars "ansible_password=${LB_PASSWORD}"
                        
                        echo "=== API Routing (optional) ==="
                        ansible loadbalancer -i inventory -m shell \
                            -a "curl -sf --max-time 5 -o /dev/null -w '%{http_code}' http://localhost/api/employees || echo 'Backend not deployed yet'" \
                            --extra-vars "ansible_password=${LB_PASSWORD}"
                    '''
                }
                echo "✅ All validation checks passed"
            }
        }
    }
    
    post {
        success {
            echo """
            ✅ Frontend CI/CD Pipeline Completed Successfully!
         
        }
        
        failure {
            echo "❌ Frontend CI/CD pipeline failed!"
        }
        
        always {
            cleanWs()
        }
    }
}
