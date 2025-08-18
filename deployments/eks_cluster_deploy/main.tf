# =============================================
# EKS Deployment — single apply, no -target
# =============================================

terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    http = { source = "hashicorp/http", version = "~> 3.4" }
    null = { source = "hashicorp/null", version = "~> 3.2" }
    time = { source = "hashicorp/time", version = "~> 0.11" }
  }
}

provider "aws" {
  region = var.region[0]
}

# ------------------------------
# EKS Cluster module
# ------------------------------
module "eks_cluster" {
  source                     = "../../modules/eks"
  cluster_name               = "${var.prefix}api-${var.cluster_prefix}"
  iam_role_name              = "${var.prefix}cluster-role"
  vpc_name                   = data.aws_vpc.vpc.id
  cluster_policy             = var.cluster_policy
  resource_controller_policy = var.resource_controller_policy
  subnets                    = data.aws_subnet.subnets.*.id
  aws_region                 = var.region[0]
}

# ------------------------------
# Nodegroup module
# ------------------------------
module "nodegroup" {
  for_each                              = { for obj in var.nodegroups : obj.ng_prefix => obj }
  source                                = "../../modules/nodegroups"
  cluster_name                          = module.eks_cluster.cluster_name
  desired_size                          = each.value.desired_size
  max_size                              = each.value.max_size
  min_size                              = each.value.min_size
  launch_template                       = "${var.prefix}${each.value.ng_prefix}-template-${var.cluster_prefix}"
  node_name                             = "${var.prefix}${each.value.ng_prefix}-node-${var.cluster_prefix}"
  nodegroup_name                        = "${var.prefix}${each.value.ng_prefix}-nodegroup-${var.cluster_prefix}"
  node_role_name                        = "${var.prefix}${each.value.ng_prefix}-node-role-${var.cluster_prefix}"
  instance_type                         = each.value.instance_type
#  ssm_parameter                         = local.ssm_parameter
  ssm_parameter                         = null
  worker_node_policy                    = var.worker_node_policy
  cni_policy                            = var.cni_policy
  container_registry_read_only_policy   = var.container_registry_read_only_policy
  subnets                               = data.aws_subnet.subnets.*.id
  aws_region                            = var.region[0]
  ng_prefix                             = each.value.ng_prefix
  volume_size                           = each.value.volume_size
}

# ------------------------------
# ECR registry
# ------------------------------
module "ecr_registry" {
  source            = "../../modules/ecr"
  ecr_registry_name = "${var.prefix}dev"
}

# ------------------------------
# Subnet tags for ALB controller
# ------------------------------
resource "aws_ec2_tag" "cluster_shared" {
  count       = length(data.aws_subnet.subnets)
  resource_id = data.aws_subnet.subnets[count.index].id
  key         = "kubernetes.io/cluster/${var.prefix}api-${var.cluster_prefix}"
  value       = "shared"
}

resource "aws_ec2_tag" "role_elb" {
  count       = length(data.aws_subnet.subnets)
  resource_id = data.aws_subnet.subnets[count.index].id
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

# ------------------------------
# IRSA + IAM for AWS Load Balancer Controller
# (safe to create before cluster)
# ------------------------------

# Get the official controller policy JSON
data "http" "alb_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.13.3/docs/install/iam_policy.json"
}

# OIDC provider for IRSA (requires cluster to exist; we create it AFTER the cluster is up)
resource "aws_iam_openid_connect_provider" "eks" {
  url             = "https://oidc.eks.${var.region[0]}.amazonaws.com/id/${module.eks_cluster.cluster_id}" # use your module output if available; else swap to data source post-wait (see null_resource below)
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0ecd4e0c3"]

  depends_on = [module.eks_cluster]
}

# Assume-role policy for the controller SA
data "aws_iam_policy_document" "alb_sa_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::216026633254:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/9856A945C800BA16282CF558F8DED7CE"]
    }

    condition {
      test     = "StringEquals"
      variable = "oidc.eks.us-east-1.amazonaws.com/id/9856A945C800BA16282CF558F8DED7CE:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "oidc.eks.us-east-1.amazonaws.com/id/9856A945C800BA16282CF558F8DED7CE:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "alb_controller" {
  name               = "${var.prefix}lb-controller-${var.cluster_prefix}"
  assume_role_policy = data.aws_iam_policy_document.alb_sa_assume.json

  depends_on = [module.eks_cluster]
}

resource "aws_iam_policy" "alb_controller" {
  name   = "${var.prefix}AWSLoadBalancerControllerIAMPolicy"
  policy = data.http.alb_policy.response_body
}

resource "aws_iam_role_policy_attachment" "alb_attach" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

# ------------------------------
# Wait for cluster to be ACTIVE, then install ALB controller via Helm CLI
# ------------------------------

# Small backoff so the EKS API is reachable
resource "time_sleep" "post_cluster_wait" {
  create_duration = "60s"
  depends_on      = [module.eks_cluster, module.nodegroup]
}

# Install using local-exec so we don't initialize Helm/K8s providers pre-cluster
resource "null_resource" "install_alb_controller" {
  depends_on = [
    time_sleep.post_cluster_wait,
    aws_iam_role.alb_controller,
    aws_iam_role_policy_attachment.alb_attach,
    aws_ec2_tag.cluster_shared,
    aws_ec2_tag.role_elb
  ]

  # Re-run if policy/role change
  triggers = {
    role_arn   = aws_iam_role.alb_controller.arn
    policy_sha = sha1(data.http.alb_policy.response_body)
    cluster    = module.eks_cluster.cluster_name
    region     = var.region[0]
    vpc_id     = data.aws_vpc.vpc.id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = <<-EOT
      set -euo pipefail

      # Ensure cluster is active
      aws eks wait cluster-active --name "${module.eks_cluster.cluster_name}" --region "${var.region[0]}"

      # Kubeconfig
      aws eks update-kubeconfig --name "${module.eks_cluster.cluster_name}" --region "${var.region[0]}"

      # Create SA with IRSA annotation
      kubectl -n kube-system create serviceaccount aws-load-balancer-controller --dry-run=client -o yaml \
        | kubectl apply -f -
      kubectl -n kube-system annotate serviceaccount aws-load-balancer-controller \
        eks.amazonaws.com/role-arn="${aws_iam_role.alb_controller.arn}" --overwrite

      # Install/upgrade ALB Controller via Helm
      helm repo add eks https://aws.github.io/eks-charts
      helm repo update
      helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName="${module.eks_cluster.cluster_name}" \
        --set region="${var.region[0]}" \
        --set vpcId="${data.aws_vpc.vpc.id}" \
        --set serviceAccount.create=false \
        --set serviceAccount.name=aws-load-balancer-controller
    EOT
  }
}

# ------------------------------
# IRSA + IAM for EBS CSI Driver
# ------------------------------

# Assume-role policy for the EBS CSI driver SA
data "aws_iam_policy_document" "ebs_csi_sa_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::216026633254:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/9856A945C800BA16282CF558F8DED7CE"]
    }

    condition {
      test     = "StringEquals"
      variable = "oidc.eks.us-east-1.amazonaws.com/id/9856A945C800BA16282CF558F8DED7CE:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "oidc.eks.us-east-1.amazonaws.com/id/9856A945C800BA16282CF558F8DED7CE:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  name               = "${var.prefix}ebs-csi-driver-${var.cluster_prefix}"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_sa_assume.json

  depends_on = [module.eks_cluster]
}

resource "aws_iam_role_policy_attachment" "ebs_csi_attach" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# ------------------------------
# Install EBS CSI Driver
# ------------------------------
resource "null_resource" "install_ebs_csi_driver" {
  depends_on = [
    null_resource.install_alb_controller,
    aws_iam_role.ebs_csi_driver,
    aws_iam_role_policy_attachment.ebs_csi_attach
  ]

  # Re-run if role changes
  triggers = {
    role_arn = aws_iam_role.ebs_csi_driver.arn
    cluster  = module.eks_cluster.cluster_name
    region   = var.region[0]
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = <<-EOT
      set -euo pipefail

      # Ensure cluster is active and kubeconfig is updated
      aws eks wait cluster-active --name "${module.eks_cluster.cluster_name}" --region "${var.region[0]}"
      aws eks update-kubeconfig --name "${module.eks_cluster.cluster_name}" --region "${var.region[0]}"

      # Install EBS CSI Driver as EKS add-on (recommended approach)
      echo "Installing EBS CSI Driver add-on..."
      aws eks create-addon \
        --cluster-name "${module.eks_cluster.cluster_name}" \
        --addon-name aws-ebs-csi-driver \
        --service-account-role-arn "${aws_iam_role.ebs_csi_driver.arn}" \
        --resolve-conflicts OVERWRITE \
        --region "${var.region[0]}" || echo "Add-on may already exist, continuing..."

      # Wait for add-on to be active
      echo "Waiting for EBS CSI Driver add-on to be active..."
      aws eks wait addon-active \
        --cluster-name "${module.eks_cluster.cluster_name}" \
        --addon-name aws-ebs-csi-driver \
        --region "${var.region[0]}"

      # Ensure service account is properly annotated
      kubectl annotate serviceaccount ebs-csi-controller-sa -n kube-system \
        eks.amazonaws.com/role-arn="${aws_iam_role.ebs_csi_driver.arn}" --overwrite

      # Create gp3 storage class with EBS CSI driver
      cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF

      # Restart EBS CSI controller to pick up new role
      kubectl rollout restart deployment ebs-csi-controller -n kube-system
      kubectl rollout status deployment ebs-csi-controller -n kube-system --timeout=300s

      # Verify installation
      echo "Verifying EBS CSI Driver installation..."
      kubectl get pods -n kube-system | grep ebs-csi || echo "EBS CSI pods not found yet, may still be starting..."
      kubectl get storageclass | grep gp3 || echo "gp3 storage class not found yet"
      
      echo "EBS CSI Driver installation completed!"
    EOT
  }
}

# ------------------------------
# Install Grafana in monitoring namespace
# ------------------------------
resource "null_resource" "install_grafana" {
  depends_on = [
    null_resource.install_alb_controller,
    null_resource.install_ebs_csi_driver
  ]

  # Re-run if cluster or region changes
  triggers = {
    cluster = module.eks_cluster.cluster_name
    region  = var.region[0]
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = <<-EOT
      set -euo pipefail

      # Ensure cluster is active and kubeconfig is updated
      aws eks wait cluster-active --name "${module.eks_cluster.cluster_name}" --region "${var.region[0]}"
      aws eks update-kubeconfig --name "${module.eks_cluster.cluster_name}" --region "${var.region[0]}"

      # Create monitoring namespace
      kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

      # Add Grafana Helm repository
      helm repo add grafana https://grafana.github.io/helm-charts
      helm repo update

      # Install Grafana with persistent storage and ALB-ready configuration
      helm upgrade --install grafana grafana/grafana \
        --namespace monitoring \
        --set persistence.enabled=true \
        --set persistence.size=10Gi \
        --set persistence.storageClassName=gp3 \
        --set service.type=ClusterIP \
        --set service.port=80 \
        --set service.targetPort=3000 \
        --set adminPassword=admin123 \
        --set datasources."datasources\.yaml".apiVersion=1 \
        --set datasources."datasources\.yaml".datasources[0].name=Prometheus \
        --set datasources."datasources\.yaml".datasources[0].type=prometheus \
        --set datasources."datasources\.yaml".datasources[0].url=http://prometheus-server.monitoring.svc.cluster.local \
        --set datasources."datasources\.yaml".datasources[0].access=proxy \
        --set datasources."datasources\.yaml".datasources[0].isDefault=true

      # Create Ingress for public ALB access
      cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: monitoring
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}]'
    alb.ingress.kubernetes.io/healthcheck-path: /api/health
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '30'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '3'
    # SSL certificate can be added later with:
    # alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:region:account:certificate/cert-id
    # alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
    # alb.ingress.kubernetes.io/ssl-redirect: '443'
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 80
EOF

      echo "Grafana installation completed!"
      echo "Waiting for ALB to be provisioned..."
      sleep 30
      
      # Get ALB URL
      ALB_URL=$(kubectl get ingress grafana-ingress -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
      if [ ! -z "$ALB_URL" ]; then
        echo "Grafana will be accessible at: http://$ALB_URL"
        echo "Default login: admin / admin123"
      else
        echo "ALB is still provisioning. Check ingress status with:"
        echo "kubectl get ingress grafana-ingress -n monitoring"
      fi
    EOT
  }
}

# =============================================
# Your existing data sources (in data.tf)
# =============================================
# data "aws_vpc" "vpc" { tags = { Name = var.vpc_name } }
# data "aws_subnet" "subnets" { ... }
# data "aws_ssm_parameter" "eks_ami_release_version" { ... }
