# =============================================
# Data resources
# =============================================
data "aws_ssm_parameter" "eks_ami_release_version" {
  name = "/aws/service/eks/optimized-ami/${local.eks_cluster_version}/amazon-linux-2/recommended/release_version"
}

data "aws_vpc" "vpc" {
  tags = {
    Name = var.vpc_name
  }
}

data "aws_subnet" "subnets" {
    count = 3
      tags = {
            Name = var.subnets[count.index]
      }
}