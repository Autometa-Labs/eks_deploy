output "endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "kubeconfig_certificate_authority_data" {
  value = aws_eks_cluster.eks_cluster.certificate_authority[0].data
}

output "eks_version" {
  value = aws_eks_cluster.eks_cluster.version
}

output "cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.oidc_provider.arn
}

output "cluster_id" {
  value = aws_eks_cluster.eks_cluster.id
}