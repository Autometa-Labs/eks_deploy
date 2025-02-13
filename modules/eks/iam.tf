# =============================================
# IAM for EKS Cluster
# =============================================
resource "aws_iam_role" "eks_cluster_role" {
  name               = var.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy_att" {
  policy_arn = var.cluster_policy
  role       = aws_iam_role.eks_cluster_role.name
}
resource "aws_iam_role_policy_attachment" "eks_resource_controller_att" {
  policy_arn = var.resource_controller_policy
  role       = aws_iam_role.eks_cluster_role.name
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "tls_certificate" "this" {
  depends_on = [aws_eks_cluster.eks_cluster]

  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "oidc_provider" {
  depends_on = [aws_eks_cluster.eks_cluster]

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.this.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer

  tags = merge(
    { Name = "${aws_eks_cluster.eks_cluster.name}-eks_irsa" },
    local.tags
  )
}