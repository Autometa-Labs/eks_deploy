# =============================================
# IAM for EKS Nodegroups
# =============================================
resource "aws_iam_role" "eks_node_role" {
  name = var.node_role_name

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy_att" {
  policy_arn = var.worker_node_policy
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy_att" {
  policy_arn = var.cni_policy
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_read_only_att" {
  policy_arn = var.container_registry_read_only_policy
  role       = aws_iam_role.eks_node_role.name
}