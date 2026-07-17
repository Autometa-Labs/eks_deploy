# =============================================
# EKS Cluster
# =============================================
provider "aws" {
  region = var.aws_region
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  enabled_cluster_log_types = ["api", "authenticator", "audit", "scheduler", "controllerManager"]

  vpc_config {
    endpoint_private_access = true
    subnet_ids = var.subnets
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy_att,
    aws_iam_role_policy_attachment.eks_resource_controller_att,
  ]

  lifecycle {
    ignore_changes = [access_config]
  }
}