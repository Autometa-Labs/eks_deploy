# =============================================
# EKS Infrastructure Deployment - DEV Environment
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
  source                     = "../../../modules/eks"
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
  source                                = "../../../modules/nodegroups"
  cluster_name                          = module.eks_cluster.cluster_name
  desired_size                          = each.value.desired_size
  max_size                              = each.value.max_size
  min_size                              = each.value.min_size
  launch_template                       = "${var.prefix}${each.value.ng_prefix}-template-${var.cluster_prefix}"
  node_name                             = "${var.prefix}${each.value.ng_prefix}-node-${var.cluster_prefix}"
  nodegroup_name                        = "${var.prefix}${each.value.ng_prefix}-nodegroup-${var.cluster_prefix}"
  node_role_name                        = "${var.prefix}${each.value.ng_prefix}-node-role-${var.cluster_prefix}"
  instance_type                         = each.value.instance_type
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
  source            = "../../../modules/ecr"
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
# ------------------------------

# Get the official controller policy JSON
data "http" "alb_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.13.3/docs/install/iam_policy.json"
}

# Assume-role policy for the controller SA
data "aws_iam_policy_document" "alb_sa_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks_cluster.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks_cluster.oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks_cluster.oidc_issuer_url, "https://", "")}:aud"
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
# IRSA + IAM for EBS CSI Driver
# ------------------------------

# Assume-role policy for the EBS CSI driver SA
data "aws_iam_policy_document" "ebs_csi_sa_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks_cluster.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks_cluster.oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks_cluster.oidc_issuer_url, "https://", "")}:aud"
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
