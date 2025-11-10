#!/bin/bash

# PostgreSQL Deployment Script for Multiple Environments
# This script deploys PostgreSQL using Helm Chart across Dev, Test, Staging, and Prod environments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if helm is installed
check_helm() {
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed. Please install Helm first."
        exit 1
    fi
    print_info "Helm is installed: $(helm version --short)"
}

# Function to check if kubectl is installed
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    print_info "kubectl is installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
}

# Function to add Bitnami Helm repo
add_helm_repo() {
    print_info "Adding Bitnami Helm repository..."
    helm repo add bitnami https://charts.bitnami.com/bitnami || print_warning "Bitnami repo may already exist"
    helm repo update
    print_info "Helm repository updated"
}

# Function to deploy to a specific environment
deploy_environment() {
    local env=$1
    local namespace="myapp-${env}"
    local values_file="helm-values/postgresql-values-${env}.yaml"
    
    print_info "================================================"
    print_info "Deploying PostgreSQL to ${env} environment"
    print_info "================================================"
    
    # Create namespace
    print_info "Creating namespace: ${namespace}"
    kubectl apply -f k8s/namespaces/namespaces.yaml
    
    # Create secrets
    print_info "Creating database secrets for ${env}..."
    kubectl apply -f "k8s/secrets/db-secret-${env}.yaml"
    
    # Deploy PostgreSQL using Helm
    print_info "Deploying PostgreSQL using Helm..."
    helm upgrade --install myapp-db-${env} bitnami/postgresql \
        --namespace ${namespace} \
        --values ${values_file} \
        --wait \
        --timeout 5m
    
    print_info "PostgreSQL deployment completed for ${env}"
    
    # Show pod status
    print_info "Checking pod status..."
    kubectl get pods -n ${namespace} -l app.kubernetes.io/name=postgresql
    
    # Show service details
    print_info "Service details:"
    kubectl get svc -n ${namespace} -l app.kubernetes.io/name=postgresql
    
    print_info "${env} deployment completed successfully!"
    echo ""
}

# Function to show connection info
show_connection_info() {
    local env=$1
    local namespace="myapp-${env}"
    
    print_info "================================================"
    print_info "Connection information for ${env}:"
    print_info "================================================"
    echo "Host: myapp-db-${env}.${namespace}.svc.cluster.local"
    echo "Port: 5432"
    echo "Database: myapp-db"
    echo "Username: stored in secret 'myapp-db-secret' (key: username)"
    echo "Password: stored in secret 'myapp-db-secret' (key: password)"
    echo ""
    echo "To retrieve credentials:"
    echo "  kubectl get secret myapp-db-secret -n ${namespace} -o jsonpath='{.data.username}' | base64 -d"
    echo "  kubectl get secret myapp-db-secret -n ${namespace} -o jsonpath='{.data.password}' | base64 -d"
    echo ""
}

# Main script
main() {
    print_info "Starting PostgreSQL deployment across all environments"
    
    # Check prerequisites
    check_helm
    check_kubectl
    add_helm_repo
    
    # Parse command line arguments
    if [ $# -eq 0 ]; then
        # Deploy to all environments
        print_warning "No environment specified. Deploying to all environments..."
        read -p "Continue? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Deployment cancelled"
            exit 0
        fi
        
        for env in dev test staging prod; do
            deploy_environment $env
            show_connection_info $env
        done
    else
        # Deploy to specific environment
        env=$1
        if [[ ! "$env" =~ ^(dev|test|staging|prod)$ ]]; then
            print_error "Invalid environment: $env"
            print_error "Valid environments: dev, test, staging, prod"
            exit 1
        fi
        deploy_environment $env
        show_connection_info $env
    fi
    
    print_info "================================================"
    print_info "All deployments completed successfully!"
    print_info "================================================"
}

# Run main function
main "$@"
