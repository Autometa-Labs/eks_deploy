# Technical Context

## Technologies Used

### Infrastructure as Code
- **Terraform v1.5+**: Infrastructure provisioning and management
- **AWS Provider v5.0+**: AWS resource management
- **HTTP Provider v3.4+**: External data fetching (ALB controller policies)
- **TLS Provider**: Certificate handling for OIDC
- **Time Provider v0.11+**: Time-based resource management

### Container Orchestration
- **Amazon EKS v1.30**: Managed Kubernetes service
- **Kubernetes v1.30**: Container orchestration platform
- **AWS EKS Add-ons**: Native AWS service integration
- **Helm v3**: Kubernetes package management

### Configuration Management
- **Ansible v2.15+**: Application deployment automation
- **Ansible Collections**:
  - `kubernetes.core`: Kubernetes resource management
  - `amazon.aws`: AWS service integration
- **YAML**: Configuration and variable files

### Monitoring and Observability
- **Prometheus**: Metrics collection and storage
- **Grafana v12.1.0**: Visualization and dashboards
- **AlertManager**: Alert routing and management
- **Loki v2.9.3**: Log aggregation and storage
- **Promtail**: Log collection agent

### AWS Services Integration
- **Amazon EKS**: Managed Kubernetes clusters
- **Amazon EBS**: Persistent storage via CSI driver
- **Application Load Balancer (ALB)**: External service access
- **Amazon ECR**: Container image registry
- **Route53**: DNS management
- **IAM**: Identity and access management
- **VPC**: Network isolation and security

### Development Tools
- **Git**: Version control
- **GitHub**: Repository hosting
- **kubectl**: Kubernetes CLI
- **aws-cli**: AWS command line interface

## Development Setup

### Prerequisites
```bash
# Required tools and versions
terraform >= 1.5.0
ansible >= 2.15.0
kubectl >= 1.30.0
aws-cli >= 2.0.0
helm >= 3.0.0
```

### AWS Configuration
```bash
# AWS credentials and region setup
aws configure set region us-east-1
aws configure set output json

# EKS cluster access
aws eks update-kubeconfig --region us-east-1 --name dev-app-api-cl01
```

### Ansible Collections
```bash
# Required Ansible collections
ansible-galaxy collection install kubernetes.core
ansible-galaxy collection install amazon.aws
```

### Environment Variables
```bash
# Common environment variables
export AWS_REGION=us-east-1
export KUBECONFIG=~/.kube/config
export ANSIBLE_HOST_KEY_CHECKING=False
```

## Technical Constraints

### AWS Limitations
- **EKS Version Support**: Limited to supported Kubernetes versions
- **Regional Resources**: Some resources are region-specific
- **Service Limits**: AWS service quotas may limit scaling
- **Cost Considerations**: EKS control plane and worker node costs

### Kubernetes Constraints
- **Resource Limits**: Node capacity limits pod scheduling
- **Storage Classes**: Limited to EBS-backed storage
- **Network Policies**: Basic security group-based networking
- **RBAC**: Service account-based permissions

### Terraform Constraints
- **State Management**: Remote state required for team collaboration
- **Module Dependencies**: Careful ordering of resource creation
- **Provider Versions**: Compatibility between provider versions
- **Resource Limits**: AWS API rate limiting

### Ansible Constraints
- **Idempotency**: All tasks must be safely repeatable
- **Error Handling**: Comprehensive error handling for cleanup
- **Timeout Management**: Proper timeout handling for long operations
- **Dependency Management**: Correct task ordering and dependencies

## Dependencies

### External Dependencies
- **AWS Account**: Active AWS account with appropriate permissions
- **Domain Registration**: Route53 hosted zone for DNS
- **Network Infrastructure**: Existing VPC and subnets
- **SSL Certificates**: For HTTPS endpoints (optional)

### Internal Dependencies
```
Terraform Modules:
├── eks module → nodegroups module
├── eks module → ECR module
└── All modules → shared variables

Ansible Roles:
├── aws_discovery → all other roles
├── ebs_csi_driver → storage-dependent roles
├── alb_controller → ingress-dependent roles
└── monitoring roles → storage and networking roles
```

### Version Compatibility Matrix
```
Component           | Version    | Compatibility
--------------------|------------|------------------
Terraform           | v1.5+      | AWS Provider v5.0+
EKS                 | v1.30      | kubectl v1.30+
Helm Charts         | v3.0+      | Kubernetes v1.30
Ansible             | v2.15+     | Python 3.8+
AWS CLI             | v2.0+      | Python 3.8+
```

## Tool Usage Patterns

### Terraform Workflow
```bash
# Standard Terraform operations
terraform init          # Initialize backend and providers
terraform plan          # Review planned changes
terraform apply         # Apply infrastructure changes
terraform destroy       # Remove infrastructure
```

### Ansible Workflow
```bash
# Deployment patterns
ansible-playbook app_deploy.yml --extra-vars "@vars/dev-vars.yml" --tags all
ansible-playbook app_deploy.yml --extra-vars "@vars/dev-vars.yml" --tags prometheus
ansible-playbook app_destroy.yml --extra-vars "@vars/dev-vars.yml" --tags all
```

### Kubernetes Operations
```bash
# Common kubectl commands
kubectl get pods -n monitoring
kubectl get ingress -n monitoring
kubectl logs -f deployment/grafana -n monitoring
kubectl describe pod <pod-name> -n monitoring
```

### Helm Management
```bash
# Helm operations
helm list -A                    # List all releases
helm status <release> -n <ns>   # Check release status
helm uninstall <release> -n <ns> # Remove release
```

## Configuration Patterns

### Environment-Specific Variables
```yaml
# vars/dev-vars.yml pattern
env_name: "dev"
cluster_name: "dev-app-api-cl01"
aws_region: "us-east-1"
monitoring_namespace: "monitoring"
dns_domain: "collectalot.io"
```

### Terraform Variable Structure
```hcl
# Standard variable pattern
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "dev-app-api-cl01"
}
```

### Helm Values Pattern
```yaml
# Standard Helm values structure
values:
  persistence:
    enabled: true
    size: "{{ component_storage_size }}"
    storageClass: "{{ storage_class }}"
  ingress:
    enabled: false  # Managed separately
  serviceAccount:
    create: true
    annotations:
      eks.amazonaws.com/role-arn: "{{ iam_role_arn }}"
```

## Security Considerations

### IAM Best Practices
- **Least Privilege**: Minimal required permissions
- **Role-Based Access**: Service-specific IAM roles
- **IRSA Integration**: Kubernetes service account to IAM role binding
- **Policy Versioning**: Use of managed policies where possible

### Network Security
- **Private Subnets**: Worker nodes in private subnets
- **Security Groups**: Restrictive ingress/egress rules
- **Internal Services**: Loki deployed without external access
- **ALB Integration**: Controlled external access via ALB

### Secrets Management
- **Kubernetes Secrets**: For sensitive configuration
- **AWS Secrets Manager**: For external secrets (future enhancement)
- **Service Account Tokens**: Automatic token rotation
- **TLS Certificates**: Automatic certificate management

### Compliance Patterns
- **Resource Tagging**: Consistent tagging for cost allocation
- **Audit Logging**: EKS control plane logging enabled
- **Access Logging**: ALB access logs for monitoring
- **Encryption**: EBS volume encryption enabled
