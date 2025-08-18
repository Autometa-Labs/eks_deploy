# Multi-Environment EKS Deployment Architecture

This directory contains a complete separation of infrastructure and application deployments across multiple environments (dev, staging, prod).

## Architecture Overview

```
environments/
├── dev/
│   ├── infra_deploy/     # Terraform infrastructure (EKS, IAM, networking)
│   └── app_deploy/       # Ansible applications (ALB, EBS, Grafana)
├── staging/
│   ├── infra_deploy/     # Terraform infrastructure
│   └── app_deploy/       # Ansible applications
└── prod/
    ├── infra_deploy/     # Terraform infrastructure
    └── app_deploy/       # Ansible applications
```

## Key Features

### 🏗️ **Infrastructure & Application Separation**
- **Terraform** handles infrastructure (EKS clusters, IAM roles, networking)
- **Ansible** handles applications (Helm deployments, K8s resources)
- Clean separation prevents coupling issues

### 🔍 **AWS Resource Discovery**
- Ansible roles automatically discover AWS resources using cluster names
- No hardcoded values or manual configuration required
- Environment-agnostic roles work across dev/staging/prod

### 🎯 **Consistent Naming Convention**
- Cluster names follow pattern: `{env}-app-api-cl01`
- Examples: `dev-app-api-cl01`, `staging-app-api-cl01`, `prod-app-api-cl01`
- All resources use consistent prefixes for easy identification

### 🔒 **Separate State Management**
- Each environment has its own Terraform state file
- Prevents cross-environment interference
- Safe parallel deployments

## Quick Start

### 🚀 One-Liner Commands (Complete Environment)

**Deploy Everything (Infrastructure + Applications):**
```bash
# Dev environment - complete deployment
cd environments/dev/infra_deploy && terraform init && terraform apply -auto-approve && cd ../app_deploy && ansible-playbook site.yml

# Staging environment - complete deployment  
cd environments/staging/infra_deploy && terraform init && terraform apply -auto-approve && cd ../app_deploy && ansible-playbook site.yml

# Prod environment - complete deployment
cd environments/prod/infra_deploy && terraform init && terraform apply -auto-approve && cd ../app_deploy && ansible-playbook site.yml
```

**Destroy Everything (Applications + Infrastructure):**
```bash
# Dev environment - complete destruction
cd environments/dev/app_deploy && ansible-playbook app_destroy.yml --tags all && cd ../infra_deploy && terraform destroy -auto-approve

# Staging environment - complete destruction
cd environments/staging/app_deploy && ansible-playbook app_destroy.yml --tags all && cd ../infra_deploy && terraform destroy -auto-approve

# Prod environment - complete destruction  
cd environments/prod/app_deploy && ansible-playbook app_destroy.yml --tags all && cd ../infra_deploy && terraform destroy -auto-approve
```

### 1. Deploy Infrastructure (Terraform)

```bash
# Deploy dev infrastructure
cd environments/dev/infra_deploy
terraform init
terraform plan
terraform apply

# Deploy staging infrastructure
cd environments/staging/infra_deploy
terraform init
terraform plan
terraform apply

# Deploy prod infrastructure
cd environments/prod/infra_deploy
terraform init
terraform plan
terraform apply
```

### 2. Deploy Applications (Ansible)

```bash
# Deploy dev applications
cd environments/dev/app_deploy
ansible-playbook site.yml

# Deploy staging applications
cd environments/staging/app_deploy
ansible-playbook site.yml

# Deploy prod applications
cd environments/prod/app_deploy
ansible-playbook site.yml
```

## Environment Configuration

Each environment is configured through simple files:

### Terraform Configuration
- `terraform.tfvars` - Environment-specific values
- `backend.tf` - Separate state storage
- Cluster naming: `{env}-app-api-cl01`

### Ansible Configuration
- `env.yml` - Environment settings and cluster name
- Automatic AWS resource discovery
- Environment-agnostic roles

## Deployed Components

### Infrastructure (Terraform)
- ✅ EKS Cluster with consistent naming
- ✅ IAM Roles for Service Accounts (IRSA)
- ✅ Node Groups with auto-scaling
- ✅ ECR Registry per environment
- ✅ VPC subnet tagging for ALB

### Applications (Ansible)
- ✅ AWS Load Balancer Controller
- ✅ EBS CSI Driver with gp3 storage class
- ✅ Prometheus Stack (kube-prometheus-stack) with persistent storage
- ✅ Grafana with persistent storage and ALB ingress
- ✅ AlertManager with persistent storage and ALB ingress
- ✅ Route53 DNS integration for all monitoring services

## AWS Resource Discovery

The `aws_discovery` role automatically finds:
- EKS cluster details and OIDC configuration
- IAM role ARNs for service accounts
- VPC and networking information
- All resources discovered using cluster name pattern

## Usage Examples

### Deploy Specific Components
```bash
# Deploy all components
ansible-playbook site.yml --tags all
ansible-playbook site.yml  # (same as --tags all)

# Deploy only ALB controller
ansible-playbook site.yml --tags alb

# Deploy only storage components
ansible-playbook site.yml --tags storage

# Deploy only monitoring stack
ansible-playbook site.yml --tags prometheus,grafana

# Deploy only Prometheus
ansible-playbook site.yml --tags prometheus

# Deploy only Grafana
ansible-playbook site.yml --tags grafana
```

### Environment Management
```bash
# Check what will be deployed
ansible-playbook site.yml --check

# Run with verbose output
ansible-playbook site.yml -v

# Deploy to specific environment
cd environments/staging/app_deploy
ansible-playbook site.yml
```

## Destroying Applications

Each environment includes an `app_destroy.yml` playbook with **enhanced selective destruction** capabilities using Ansible tags, including comprehensive cleanup of ALB target groups and EBS volumes.

### Selective Destruction (Individual Components)
```bash
# Destroy only Prometheus Stack (includes Prometheus + AlertManager)
cd environments/dev/app_deploy
ansible-playbook app_destroy.yml --tags prometheus

# Destroy only Grafana (includes PVCs and EBS volumes)
ansible-playbook app_destroy.yml --tags grafana

# Destroy only ALB controller (includes target group cleanup)
ansible-playbook app_destroy.yml --tags alb

# Destroy only storage components (includes orphaned EBS volumes)
ansible-playbook app_destroy.yml --tags storage

# Destroy monitoring stack together
ansible-playbook app_destroy.yml --tags prometheus,grafana

# Destroy ALB controller and storage together
ansible-playbook app_destroy.yml --tags alb,storage
```

### Complete Application Destruction
```bash
# Destroy all applications using 'all' tag
cd environments/dev/app_deploy
ansible-playbook app_destroy.yml --tags all

# Destroy all applications (no tags = everything)
ansible-playbook app_destroy.yml
```

### Available Destruction Tags

| Tag | Components Destroyed |
|-----|---------------------|
| `prometheus` | Prometheus Stack (Prometheus + AlertManager), ingresses, PVCs, EBS volumes |
| `grafana` | Grafana Helm release, ingress, PVCs, EBS volumes, namespace cleanup |
| `alb` | AWS Load Balancer Controller, service accounts, target group cleanup |
| `storage` | EBS CSI Driver add-on, storage classes, orphaned EBS volume cleanup |
| `all` | All applications and comprehensive resource cleanup |

### Enhanced Cleanup Features

**`--tags grafana`**:
- ✅ Grafana ingress (triggers ALB deletion)
- ✅ Grafana Helm release
- ✅ Grafana PVCs and associated EBS volumes
- ✅ Monitoring namespace cleanup (if empty)

**`--tags alb`**:
- ✅ **ALB target group cleanup** (before controller removal)
- ✅ AWS Load Balancer Controller Helm release
- ✅ ALB controller service accounts
- ✅ Orphaned ALB cleanup

**`--tags storage`**:
- ✅ EBS CSI Driver add-on removal
- ✅ Custom gp3 storage class removal
- ✅ **Systematic PVC cleanup** (triggers EBS volume deletion)
- ✅ **Orphaned EBS volume cleanup** (cluster-tagged volumes)

**`--tags all`**:
- ✅ All components above
- ✅ Comprehensive verification and reporting
- ✅ Complete resource cleanup

### Verification and Reporting

Each destruction run includes comprehensive verification:
- ✅ Remaining Helm releases check
- ✅ Remaining ALB verification
- ✅ **Remaining target groups verification**
- ✅ **Remaining EBS volumes verification**
- ✅ Detailed destruction summary

**Note**: Infrastructure (EKS cluster, IAM roles, VPC resources) remains intact and must be destroyed separately with `terraform destroy`.

## Accessing Applications

### Complete Monitoring Stack
The deployment includes a full monitoring stack with Route53 DNS integration:

#### Grafana Dashboard
- **DNS URL**: http://grafana.collectalot.io
- **ALB URL**: Available via `kubectl get ingress grafana-ingress -n monitoring`
- **Credentials**: admin / admin123 (configurable in env.yml)
- **Features**: Pre-configured Prometheus data source, persistent storage

#### Prometheus Metrics
- **DNS URL**: http://prometheus.collectalot.io
- **ALB URL**: Available via `kubectl get ingress prometheus-ingress -n monitoring`
- **Features**: 15-day retention, 50Gi persistent storage, service discovery

#### AlertManager
- **DNS URL**: http://alertmanager.collectalot.io
- **ALB URL**: Available via `kubectl get ingress alertmanager-ingress -n monitoring`
- **Features**: 10Gi persistent storage, alert routing and notification

### Route53 DNS Integration
All monitoring services automatically get DNS records in Route53:
- Zone: `collectalot.io` (Z02467093QT0UOKUO4CKO)
- Records are automatically updated when ALB hostnames change
- 300-second TTL for fast DNS propagation

### Security Notes
- **Grafana**: Protected with built-in authentication
- **Prometheus & AlertManager**: Currently publicly accessible via ALB
- For production, consider implementing:
  - AWS Cognito integration with ALB
  - Network-level restrictions (security groups/NACLs)
  - NGINX ingress controller with basic auth
  - VPN access requirements

### Dependency Installation
Before running Ansible playbooks, install required Python dependencies:

```bash
# Install dependencies (run once per machine)
ansible-playbook setup-dependencies.yml
```

This installs: boto3, botocore, passlib, bcrypt for AWS and authentication modules.

## Troubleshooting

### Common Issues
1. **OIDC Provider Not Found**: Ensure infrastructure is deployed first
2. **ALB Not Provisioning**: Check subnet tags and ALB controller logs
3. **Storage Issues**: Verify EBS CSI driver is running and gp3 storage class exists

### Useful Commands
```bash
# Check cluster status
aws eks describe-cluster --name dev-app-api-cl01

# Verify OIDC provider
aws iam list-open-id-connect-providers

# Check Kubernetes resources
kubectl get pods -A
kubectl get ingress -A
kubectl get storageclass
```

## Security Considerations

- IAM roles use least-privilege access
- OIDC providers enable secure service account authentication
- Separate environments prevent cross-contamination
- State files stored securely in S3

## Next Steps

1. **SSL/TLS**: Add ACM certificates to ALB ingress
2. **Monitoring**: Deploy Prometheus for complete observability stack
3. **Secrets**: Implement AWS Secrets Manager integration
4. **CI/CD**: Automate deployments with GitOps workflows
5. **Backup**: Configure EBS snapshot policies

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Ansible playbook logs
3. Verify AWS resource discovery is working
4. Ensure consistent naming conventions are followed
