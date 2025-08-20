# Consolidated Multi-Environment EKS Deployment Architecture

This repository contains a consolidated deployment structure with complete separation of infrastructure and application deployments across multiple environments (dev, staging, prod).

## New Consolidated Architecture

```
eks_deploy/
├── app_deploy/                       # 🆕 CONSOLIDATED APPLICATION DEPLOYMENT
│   ├── ansible.cfg
│   ├── app_deploy.yml               # Main deployment playbook
│   ├── app_destroy.yml              # Destruction playbook
│   ├── inventory/hosts.yml
│   ├── vars/                        # 🆕 Environment-specific variables
│   │   ├── dev-vars.yml            # Dev environment configuration
│   │   ├── staging-vars.yml        # Staging environment configuration
│   │   └── prod-vars.yml           # Production environment configuration
│   └── roles/                       # 🆕 Consolidated roles (single source of truth)
│       ├── aws_discovery/          # AWS resource discovery
│       ├── alb_controller/         # AWS Load Balancer Controller
│       ├── ebs_csi_driver/         # EBS CSI Driver
│       ├── loki/                   # 🆕 Loki log aggregation stack
│       ├── prometheus/             # Prometheus monitoring stack
│       └── grafana/                # Grafana with Prometheus + Loki data sources
├── infra_deploy/                     # 🆕 SIMPLIFIED INFRASTRUCTURE DEPLOYMENT
│   ├── dev/                        # Dev environment Terraform code
│   ├── staging/                    # Staging environment Terraform code
│   └── prod/                       # Production environment Terraform code
└── modules/                        # Terraform modules
    ├── alb/
    ├── ec2/
    ├── ecr/
    ├── eks/
    ├── nodegroups/
    └── records/
```

## Key Improvements

### 🎯 **Consolidated Structure**
- **Single source of truth** for all Ansible roles
- **DRY principle** - no more duplicate code across environments
- **Environment-specific variables** in dedicated files
- **Easier maintenance** - update once, deploy everywhere

### 📋 **Enhanced Logging with Loki**
- **Loki stack** for centralized log aggregation
- **Promtail** for log collection with JSON parsing
- **pt-app-dev integration** - structured log collection from pt-app-dev namespace
- **Grafana integration** - both Prometheus (metrics) and Loki (logs) data sources

### 🔍 **pt-app-dev Log Collection**
- **Namespace**: `pt-app-dev`
- **Job**: `pt-app-dev-pokemon`
- **JSON parsing** enabled for structured logs
- **Labels extracted**: level, logger, game, run_id, app
- **Optimized** for Python application structured logging

## Quick Start

### 🚀 **One-Liner Commands**

**Complete Environment Deployment (Infrastructure + Applications):**
```bash
# Dev environment
cd infra_deploy/dev && terraform init && terraform apply -auto-approve && cd ../../app_deploy && ansible-playbook app_deploy.yml --extra-vars "@vars/dev-vars.yml"

# Staging environment
cd infra_deploy/staging && terraform init && terraform apply -auto-approve && cd ../../app_deploy && ansible-playbook app_deploy.yml --extra-vars "@vars/staging-vars.yml"

# Production environment
cd infra_deploy/prod && terraform init && terraform apply -auto-approve && cd ../../app_deploy && ansible-playbook app_deploy.yml --extra-vars "@vars/prod-vars.yml"
```

**Complete Environment Destruction (Applications + Infrastructure):**
```bash
# Dev environment
cd app_deploy && ansible-playbook app_destroy.yml --extra-vars "@vars/dev-vars.yml" --tags all && cd ../infra_deploy/dev && terraform destroy -auto-approve

# Staging environment
cd app_deploy && ansible-playbook app_destroy.yml --extra-vars "@vars/staging-vars.yml" --tags all && cd ../infra_deploy/staging && terraform destroy -auto-approve

# Production environment
cd app_deploy && ansible-playbook app_destroy.yml --extra-vars "@vars/prod-vars.yml" --tags all && cd ../infra_deploy/prod && terraform destroy -auto-approve
```

### 🏗️ **Infrastructure Deployment (Terraform)**

**Deploy Infrastructure:**
```bash
# Dev environment
cd infra_deploy/dev
terraform init
terraform apply -auto-approve

# Staging environment
cd infra_deploy/staging
terraform init
terraform apply -auto-approve

# Production environment
cd infra_deploy/prod
terraform init
terraform apply -auto-approve
```

**Destroy Infrastructure:**
```bash
# Dev environment
cd infra_deploy/dev
terraform destroy -auto-approve

# Staging environment
cd infra_deploy/staging
terraform destroy -auto-approve

# Production environment
cd infra_deploy/prod
terraform destroy -auto-approve
```

### 🚀 **Application Deployment (Ansible)**

**Deploy Applications:**
```bash
# Deploy to dev environment
cd app_deploy
ansible-playbook app_deploy.yml --extra-vars "@vars/dev-vars.yml"

# Deploy to staging environment
ansible-playbook app_deploy.yml --extra-vars "@vars/staging-vars.yml"

# Deploy to production environment
ansible-playbook app_deploy.yml --extra-vars "@vars/prod-vars.yml"
```

**Selective Component Deployment:**
```bash
# Deploy only Loki logging stack
ansible-playbook app_deploy.yml --extra-vars "@vars/dev-vars.yml" --tags loki

# Deploy only monitoring stack (Prometheus + Grafana)
ansible-playbook app_deploy.yml --extra-vars "@vars/dev-vars.yml" --tags prometheus,grafana

# Deploy all monitoring components (Loki + Prometheus + Grafana)
ansible-playbook app_deploy.yml --extra-vars "@vars/dev-vars.yml" --tags monitoring
```

**Destroy Applications:**
```bash
# Destroy specific components
ansible-playbook app_destroy.yml --extra-vars "@vars/dev-vars.yml" --tags loki

# Destroy all applications
ansible-playbook app_destroy.yml --extra-vars "@vars/dev-vars.yml" --tags all
ansible-playbook app_destroy.yml --extra-vars "@vars/dev-vars.yml"  # (same as --tags all)
```

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
- ✅ **Loki Stack** with Promtail for log aggregation (internal-only)
- ✅ Prometheus Stack (kube-prometheus-stack) with persistent storage
- ✅ Grafana with **dual data sources** (Prometheus + Loki)
- ✅ AlertManager with persistent storage and ALB ingress
- ✅ Route53 DNS integration for all services

## Complete Observability Stack

### 📊 Access URLs
- **Grafana**: http://grafana.collectalot.io (admin / admin123)
- **Prometheus**: http://prometheus.collectalot.io
- **AlertManager**: http://alertmanager.collectalot.io
- **Loki**: Internal-only service (no external access) 🔒

### 📈 Data Sources in Grafana
1. **Prometheus** (metrics) - Default data source
2. **Loki** (logs) - Configured for log exploration

### ⚠️ **Important: Loki Access**
**Loki is INTERNAL-ONLY and has NO web UI!** It's an API-only service for log storage and querying.

**Security Design:**
- **No external ALB/ingress** for Loki (security best practice)
- **Internal cluster access only** via `http://loki.monitoring.svc.cluster.local:3100`
- **Grafana accesses Loki internally** within the cluster

**To access logs:**
1. **Use Grafana** → Go to **Explore** → Select **Loki** data source (recommended)
2. **Direct API access** (internal only):
   - Port-forward: `kubectl port-forward -n monitoring svc/loki 3100:3100`
   - Then access: `http://localhost:3100/ready` or `http://localhost:3100/metrics`

### 🔍 pt-app-dev Log Queries

**Useful LogQL queries for pt-app-dev:**
```logql
# All pt-app-dev logs
{namespace="pt-app-dev"}

# Error logs only
{namespace="pt-app-dev"} | json | level="ERROR"

# Job progress tracking
{namespace="pt-app-dev"} | json | logger="src.pricing_ingestion_service"

# Game-specific processing (Pokemon)
{namespace="pt-app-dev"} | json | game="Pokemon"

# Specific run tracking
{namespace="pt-app-dev"} | json | run_id="specific-run-id"

# Filter by log level and message content
{namespace="pt-app-dev"} | json | level="INFO" | line_format "{{.msg}}"
```

### 📝 Structured Log Fields Available
- `timestamp` - ISO timestamp
- `level` - Log level (INFO, WARNING, ERROR, DEBUG)
- `logger` - Python logger name
- `msg` - Log message
- `pod_name` - Kubernetes pod name
- `namespace` - Always `pt-app-dev`
- `job_name` - Always `pt-app-dev-pokemon`
- `run_id` - Unique run identifier
- `game` - Game type being processed (e.g., "Pokemon")
- `product_id` - Product being processed (when applicable)

## Environment Configuration

### Variable Files Structure
Each environment has its own variable file with appropriate sizing:

**Dev Environment** (`dev-vars.yml`):
- Grafana: 10Gi storage
- Prometheus: 50Gi storage, 15d retention
- Loki: 50Gi storage, 30d retention

**Staging Environment** (`staging-vars.yml`):
- Grafana: 20Gi storage
- Prometheus: 100Gi storage, 30d retention
- Loki: 100Gi storage, 60d retention

**Production Environment** (`prod-vars.yml`):
- Grafana: 50Gi storage
- Prometheus: 200Gi storage, 90d retention
- Loki: 200Gi storage, 90d retention

## Available Deployment Tags

### Component Tags
| Tag | Components Deployed |
|-----|-------------------|
| `loki` | Loki logging stack with Promtail (internal-only) |
| `prometheus` | Prometheus monitoring stack (Prometheus + AlertManager) |
| `grafana` | Grafana with Prometheus + Loki data sources |
| `alb` | AWS Load Balancer Controller |
| `ebs` | EBS CSI Driver and storage classes |
| `monitoring` | All monitoring components (Loki + Prometheus + Grafana) |
| `controllers` | Infrastructure controllers (ALB + EBS) |
| `all` | All applications and resources |

### Destruction Tags
| Tag | Components Destroyed |
|-----|---------------------|
| `loki` | Loki stack, PVCs, EBS volumes (no ALB to destroy) |
| `prometheus` | Prometheus stack, ingresses, PVCs, EBS volumes |
| `grafana` | Grafana, ingress, PVCs, EBS volumes |
| `alb` | ALB controller, service accounts, target group cleanup |
| `storage` | EBS CSI Driver, storage classes, orphaned volume cleanup |
| `all` | All applications and comprehensive resource cleanup |

## Migration from Old Structure

The old structure has been completely consolidated:
- ~~`deployments/eks_cluster_deploy/`~~ → Removed (no longer needed)
- ~~`environments/dev/app_deploy/`~~ → `app_deploy/` + `vars/dev-vars.yml`
- ~~`environments/staging/app_deploy/`~~ → `app_deploy/` + `vars/staging-vars.yml`
- ~~`environments/prod/app_deploy/`~~ → `app_deploy/` + `vars/prod-vars.yml`

## Benefits of New Architecture

### 🔧 **Maintenance**
- **Single codebase** for all environments
- **Consistent deployments** across dev/staging/prod
- **Easier updates** - modify once, deploy everywhere
- **Reduced repository size** - eliminated duplicate code

### 📊 **Observability**
- **Complete logging solution** with Loki + Promtail
- **Structured log parsing** for pt-app-dev application
- **Unified Grafana interface** for metrics and logs
- **Production-ready** monitoring stack

### 🚀 **Operations**
- **Environment-specific sizing** via variable files
- **Selective deployment** with granular tags
- **Enhanced destruction** with comprehensive cleanup
- **DNS integration** for all services

### 🔒 **Security**
- **Loki internal-only** - no external exposure of log data
- **Reduced attack surface** - fewer external endpoints
- **Best practices** - log aggregation services kept internal

## Troubleshooting

### Common Issues
1. **Variable file not found**: Ensure you're using `--extra-vars "@vars/env-vars.yml"`
2. **Loki not collecting logs**: Check Promtail pods are running on all nodes
3. **Grafana data sources**: Verify both Prometheus and Loki are accessible
4. **pt-app-dev logs**: Ensure the application is running in `pt-app-dev` namespace
5. **Loki 404 error**: This is normal - Loki has no web UI, use Grafana Explore instead

### Useful Commands
```bash
# Check all monitoring pods
kubectl get pods -n monitoring

# Check pt-app-dev application
kubectl get pods -n pt-app-dev

# Check Loki log collection
kubectl logs -n monitoring -l app=loki-promtail

# Test Grafana data sources
kubectl port-forward -n monitoring svc/grafana 3000:80
# Then access http://localhost:3000

# Test Loki API directly
kubectl port-forward -n monitoring svc/loki 3100:3100
# Then access http://localhost:3100/ready
```

## Manual Cleanup Required

If you have existing Loki ALB and target groups from previous deployments, manually clean them up:

```bash
# Find and delete Loki ALBs
aws elbv2 describe-load-balancers --region us-east-1 --query 'LoadBalancers[?contains(LoadBalancerName, `loki`)].LoadBalancerArn' --output text | xargs -r -n1 aws elbv2 delete-load-balancer --region us-east-1 --load-balancer-arn

# Find and delete Loki target groups
aws elbv2 describe-target-groups --region us-east-1 --query 'TargetGroups[?contains(TargetGroupName, `loki`)].TargetGroupArn' --output text | xargs -r -n1 aws elbv2 delete-target-group --region us-east-1 --target-group-arn

# Delete Loki DNS record
aws route53 change-resource-record-sets --hosted-zone-id YOUR_ZONE_ID --change-batch '{"Changes":[{"Action":"DELETE","ResourceRecordSet":{"Name":"loki.collectalot.io","Type":"CNAME","TTL":300,"ResourceRecords":[{"Value":"old-alb-url"}]}}]}'
```

## Security Considerations

- IAM roles use least-privilege access
- OIDC providers enable secure service account authentication
- Separate environments prevent cross-contamination
- State files stored securely in S3
- **Loki is internal-only** for enhanced security
- **Note**: Other services are publicly accessible via ALB for demo purposes

## Next Steps

1. **SSL/TLS**: Add ACM certificates to ALB ingress
2. **Authentication**: Implement AWS Cognito integration
3. **Alerting**: Configure AlertManager with Slack/email notifications
4. **Dashboards**: Create custom Grafana dashboards for pt-app-dev
5. **CI/CD**: Automate deployments with GitOps workflows

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Ansible playbook logs with `-v` flag
3. Verify AWS resource discovery is working
4. Test log queries in Grafana's Explore section
