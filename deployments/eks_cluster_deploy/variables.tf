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