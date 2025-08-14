## VPC
variable "vpc_name" {}
variable "region" {}
variable "subnets" {type = list(any)}
## EKS Cluster
variable "prefix" {}
variable "cluster_prefix" {}
## IAM
variable "worker_node_policy" {}
variable "cni_policy" {}
variable "container_registry_read_only_policy" {}
variable "cluster_policy" {}
variable "resource_controller_policy" {}
## Nodegroup configuration
variable "nodegroups" {
  type = list(object({
    desired_size = string
    max_size = string
    min_size = string
    instance_type = string
    ng_prefix = string
    volume_size = string
  }))
}

variable "eks_version" {
  description = "EKS Kubernetes version used for AMI lookups (e.g., 1.30 or 1.31)"
  type        = string
  default     = "1.30"
  validation {
    condition     = can(regex("^1\\.(2[7-9]|30|31)$", var.eks_version)) # allow 1.27–1.31
    error_message = "Set eks_version to a supported minor like 1.29, 1.30, or 1.31."
  }
}
