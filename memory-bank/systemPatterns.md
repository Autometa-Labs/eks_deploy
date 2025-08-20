# System Patterns and Architecture

## Overall Architecture

### High-Level Design
```
┌─────────────────────────────────────────────────────────────┐
│                    EKS Deploy Project                       │
├─────────────────────────────────────────────────────────────┤
│  Infrastructure Layer (Terraform)                          │
│  ├── EKS Cluster + Node Groups                            │
│  ├── IAM Roles (ALB Controller, EBS CSI Driver)           │
│  ├── ECR Repository                                       │
│  └── Subnet Tags for ALB Integration                      │
├─────────────────────────────────────────────────────────────┤
│  Application Layer (Ansible)                              │
│  ├── AWS Load Balancer Controller                         │
│  ├── EBS CSI Driver + Storage Classes                     │
│  ├── Loki Stack (Internal-only)                          │
│  ├── Prometheus Stack (External ALB)                      │
│  └── Grafana (External ALB)                              │
├─────────────────────────────────────────────────────────────┤
│  Access Layer                                             │
│  ├── Route53 DNS Records                                  │
│  ├── Application Load Balancers                           │
│  └── Kubernetes Ingress Resources                         │
└─────────────────────────────────────────────────────────────┘
```

### Directory Structure Pattern
```
eks_deploy/
├── infra_deploy/           # Infrastructure as Code
│   ├── dev/               # Environment-specific Terraform
│   ├── staging/           # Identical structure per environment
│   └── prod/              # Direct access to Terraform files
├── app_deploy/            # Application Deployment
│   ├── roles/             # Ansible roles (reusable components)
│   ├── vars/              # Environment-specific variables
│   ├── app_deploy.yml     # Main deployment playbook
│   └── app_destroy.yml    # Comprehensive cleanup playbook
├── modules/               # Terraform modules (shared)
│   ├── eks/               # EKS cluster module
│   ├── nodegroups/        # Node group module
│   └── ecr/               # ECR repository module
└── memory-bank/           # Project documentation and context
```

## Key Technical Decisions

### Infrastructure Patterns

#### Terraform Module Design
- **Modular Architecture**: Separate modules for EKS, node groups, ECR
- **Environment Isolation**: Per-environment Terraform state
- **Shared Modules**: Common modules referenced by all environments
- **Module Path Pattern**: `../../modules/` from environment directories

#### State Management
- **Remote State**: S3 backend for Terraform state
- **State Isolation**: Separate state files per environment
- **Locking**: DynamoDB for state locking (configured in backend.tf)

### Application Deployment Patterns

#### Ansible Role Structure
- **Single Source of Truth**: One app_deploy directory for all environments
- **Environment Variables**: External variable files (dev-vars.yml, staging-vars.yml, prod-vars.yml)
- **Role-Based Organization**: Each component as separate Ansible role
- **Idempotent Operations**: All tasks designed for repeated execution

#### Helm Integration Pattern
```yaml
# Standard Helm deployment pattern used across all roles
- name: Deploy [Component] via Helm
  kubernetes.core.helm:
    name: [component-name]
    chart_ref: [chart-reference]
    release_namespace: "{{ monitoring_namespace }}"
    create_namespace: true
    values: [component-specific-values]
    wait: true
    wait_timeout: 300s  # Fixed timeout format
```

### Security Patterns

#### IAM and RBAC
- **IRSA (IAM Roles for Service Accounts)**: Secure AWS service integration
- **Least Privilege**: Minimal required permissions for each component
- **Service Account Binding**: Kubernetes service accounts linked to IAM roles

#### Network Security
- **Internal-Only Services**: Loki deployed without external access
- **ALB Integration**: External services use AWS Application Load Balancer
- **Subnet Tagging**: Proper tags for ALB controller subnet discovery

### Storage Patterns

#### Persistent Storage Strategy
- **EBS CSI Driver**: Native AWS EBS integration
- **gp3 Storage Class**: Cost-effective, high-performance storage
- **Persistent Volume Claims**: Automatic volume provisioning
- **Cleanup Automation**: Automated PVC and EBS volume cleanup

#### Storage Allocation
- **Loki**: 50Gi for log storage with 30-day retention
- **Prometheus**: 50Gi for metrics with 15-day retention
- **AlertManager**: 10Gi for alert state
- **Grafana**: 10Gi for dashboards and configuration

### Monitoring and Logging Patterns

#### Observability Stack Design
```
Application Logs → Promtail → Loki (Internal) → Grafana
Application Metrics → Prometheus → Grafana
Alerts → AlertManager → External Notifications
```

#### Log Collection Pattern
- **Namespace-Specific**: Promtail configured for specific namespaces
- **JSON Parsing**: Structured log parsing for Python applications
- **Label Extraction**: Automatic extraction of level, logger, game, run_id
- **Internal Access**: Loki accessible only within cluster

### Deployment Patterns

#### One-Liner Command Pattern
```bash
# Deploy Pattern
cd infra_deploy/dev && terraform apply -auto-approve && cd ../../app_deploy && ansible-playbook app_deploy.yml --extra-vars "@vars/dev-vars.yml" --tags all

# Destroy Pattern
cd app_deploy && ansible-playbook app_destroy.yml --extra-vars "@vars/dev-vars.yml" --tags all && cd ../infra_deploy/dev && terraform destroy -auto-approve
```

#### Error Handling Pattern
- **Ignore Errors**: Strategic use of `ignore_errors: true` for cleanup operations
- **Retry Logic**: Automatic retries for time-dependent operations
- **Verification Steps**: Post-deployment checks to ensure success
- **Comprehensive Cleanup**: Multi-stage cleanup with verification

### Component Relationships

#### Critical Dependencies
1. **EKS Cluster** → **Node Groups** → **Application Pods**
2. **IAM Roles** → **Service Accounts** → **AWS Service Integration**
3. **EBS CSI Driver** → **Storage Classes** → **Persistent Volumes**
4. **ALB Controller** → **Ingress Resources** → **Load Balancers**
5. **Route53** → **DNS Records** → **Service Discovery**

#### Service Communication
- **Grafana** ↔ **Prometheus** (metrics queries)
- **Grafana** ↔ **Loki** (log queries)
- **Prometheus** ↔ **AlertManager** (alert routing)
- **Promtail** → **Loki** (log shipping)
- **Applications** → **Prometheus** (metrics scraping)

## Critical Implementation Paths

### Deployment Sequence
1. **Infrastructure Creation**: Terraform applies AWS resources
2. **Cluster Access**: Update kubeconfig for cluster access
3. **Core Services**: Deploy ALB Controller and EBS CSI Driver
4. **Storage Setup**: Create storage classes and verify functionality
5. **Monitoring Stack**: Deploy Loki, Prometheus, Grafana in sequence
6. **Network Setup**: Create ingresses and Route53 records
7. **Verification**: Confirm all services are healthy and accessible

### Cleanup Sequence
1. **Application Removal**: Uninstall Helm releases
2. **Resource Cleanup**: Remove PVCs, ingresses, service accounts
3. **AWS Resource Cleanup**: Delete ALBs, target groups, EBS volumes
4. **Infrastructure Removal**: Terraform destroys remaining resources
5. **Verification**: Confirm no orphaned resources remain

### Error Recovery Patterns
- **Timeout Handling**: Proper timeout formats for Helm operations
- **Finalizer Management**: Force removal of stuck Kubernetes resources
- **Resource Verification**: Check for orphaned resources after operations
- **State Consistency**: Ensure Terraform and Kubernetes states align
