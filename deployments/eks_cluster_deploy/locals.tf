# =============================================
# Local variables
# =============================================
locals {
  ## Naming convention parameters
  # naming_convention = module.naming_convention
  # primary = module.naming_convention.primary_network.global_shared_services

  ## Nodegroups
  eks_cluster_version = module.eks_cluster.eks_version
#  ssm_parameter = nonsensitive(data.aws_ssm_parameter.eks_ami_release_version.value)
}