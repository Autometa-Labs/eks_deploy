#!/bin/bash
# =============================================
# Multi-Environment Deployment Test Script
# Tests the complete deployment and destruction workflow
# =============================================

set -e

ENVIRONMENT=${1:-dev}
ACTION=${2:-deploy}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed"
        exit 1
    fi
    
    # Check if ansible is installed
    if ! command -v ansible-playbook &> /dev/null; then
        print_error "Ansible is not installed"
        exit 1
    fi
    
    # Check if aws cli is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        exit 1
    fi
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed"
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

# Function to deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying infrastructure for $ENVIRONMENT environment..."
    
    cd "environments/$ENVIRONMENT/infra_deploy"
    
    print_status "Initializing Terraform..."
    terraform init
    
    print_status "Planning Terraform deployment..."
    terraform plan
    
    print_status "Applying Terraform configuration..."
    terraform apply -auto-approve
    
    print_success "Infrastructure deployment completed"
    cd - > /dev/null
}

# Function to deploy applications
deploy_applications() {
    print_status "Deploying applications for $ENVIRONMENT environment..."
    
    cd "environments/$ENVIRONMENT/app_deploy"
    
    print_status "Running Ansible playbook..."
    ansible-playbook site.yml -v
    
    print_success "Application deployment completed"
    cd - > /dev/null
}

# Function to destroy applications
destroy_applications() {
    print_status "Destroying applications for $ENVIRONMENT environment..."
    
    cd "environments/$ENVIRONMENT/app_deploy"
    
    print_status "Running Ansible destroy playbook..."
    ansible-playbook app_destroy.yml -v
    
    print_success "Application destruction completed"
    cd - > /dev/null
}

# Function to destroy infrastructure
destroy_infrastructure() {
    print_status "Destroying infrastructure for $ENVIRONMENT environment..."
    
    cd "environments/$ENVIRONMENT/infra_deploy"
    
    print_status "Running Terraform destroy..."
    terraform destroy -auto-approve
    
    print_success "Infrastructure destruction completed"
    cd - > /dev/null
}

# Function to verify deployment
verify_deployment() {
    print_status "Verifying deployment for $ENVIRONMENT environment..."
    
    # Check if cluster exists
    CLUSTER_NAME="$ENVIRONMENT-app-api-cl01"
    if aws eks describe-cluster --name "$CLUSTER_NAME" --region us-east-1 &> /dev/null; then
        print_success "EKS cluster $CLUSTER_NAME exists"
    else
        print_error "EKS cluster $CLUSTER_NAME not found"
        return 1
    fi
    
    # Update kubeconfig
    aws eks update-kubeconfig --name "$CLUSTER_NAME" --region us-east-1
    
    # Check if nodes are ready
    NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
    if [ "$NODE_COUNT" -gt 0 ]; then
        print_success "$NODE_COUNT nodes are available"
    else
        print_error "No nodes found in cluster"
        return 1
    fi
    
    # Check if ALB controller is running
    if kubectl get deployment aws-load-balancer-controller -n kube-system &> /dev/null; then
        print_success "AWS Load Balancer Controller is deployed"
    else
        print_warning "AWS Load Balancer Controller not found"
    fi
    
    # Check if EBS CSI driver is running
    if kubectl get pods -n kube-system | grep ebs-csi &> /dev/null; then
        print_success "EBS CSI Driver is running"
    else
        print_warning "EBS CSI Driver not found"
    fi
    
    # Check if Grafana is running
    if kubectl get deployment grafana -n monitoring &> /dev/null; then
        print_success "Grafana is deployed"
        
        # Get ALB URL if available
        ALB_URL=$(kubectl get ingress grafana-ingress -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [ ! -z "$ALB_URL" ]; then
            print_success "Grafana ALB URL: http://$ALB_URL"
        else
            print_warning "Grafana ALB still provisioning..."
        fi
    else
        print_warning "Grafana not found"
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [ENVIRONMENT] [ACTION]"
    echo ""
    echo "ENVIRONMENT: dev, staging, or prod (default: dev)"
    echo "ACTION: deploy, destroy, verify, or full (default: deploy)"
    echo ""
    echo "Examples:"
    echo "  $0 dev deploy          # Deploy infrastructure and applications to dev"
    echo "  $0 staging destroy     # Destroy applications and infrastructure in staging"
    echo "  $0 prod verify         # Verify prod deployment"
    echo "  $0 dev full            # Full deployment with verification"
}

# Main execution
main() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        show_usage
        exit 0
    fi
    
    if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "prod" ]; then
        print_error "Invalid environment: $ENVIRONMENT"
        show_usage
        exit 1
    fi
    
    print_status "Starting $ACTION for $ENVIRONMENT environment"
    
    check_prerequisites
    
    case $ACTION in
        "deploy")
            deploy_infrastructure
            deploy_applications
            ;;
        "destroy")
            destroy_applications
            destroy_infrastructure
            ;;
        "verify")
            verify_deployment
            ;;
        "full")
            deploy_infrastructure
            deploy_applications
            verify_deployment
            ;;
        *)
            print_error "Invalid action: $ACTION"
            show_usage
            exit 1
            ;;
    esac
    
    print_success "Operation completed successfully!"
}

# Run main function with all arguments
main "$@"
