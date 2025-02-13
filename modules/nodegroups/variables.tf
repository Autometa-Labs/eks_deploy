variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
  default     = null
}

variable "desired_size" {
  type        = string
  description = "Desired size"
  default     = null
}

variable "max_size" {
  type        = string
  description = "Max size"
  default     = null
}
variable "volume_size" {
  type        = string
  description = "Volume size"
  default     = null
}

variable "min_size" {
  type        = string
  description = "Min size"
  default     = null
}

variable "launch_template" {
  type        = string
  description = "ASG launch template for node group"
  default     = null
}

variable "node_name" {
  type        = string
  description = "Node name"
  default     = null
}

variable "nodegroup_name" {
  type        = string
  description = "Nodegroup name"
  default     = null
}

variable "node_role_name" {
  type        = string
  description = "Node IAM role name"
  default     = null
}

variable "instance_type" {
  type        = string
  description = "Instance type for nodegroup"
  default     = null
}

variable "worker_node_policy" {
  type        = string
  description = "Worker node IAM policy"
  default     = null
}

variable "cni_policy" {
  type        = string
  description = "Container Netowrk Interface IAM policy"
  default     = null
}

variable "container_registry_read_only_policy" {
  type        = string
  description = "Container registry ReadOnly IAM policy"
  default     = null
}

variable "release_version" {
  type        = string
  description = "Release version"
  default     = null
}

variable "ssm_parameter" {
  type        = string
  description = "SSM parameter"
  default     = null
}

variable "subnets" {type = list(any)}

variable "aws_region" {
  description = "Region where VPC is deployed"
  type        = string
  default     = null
}

variable "ng_prefix" {
  description = "node group prefix"
  type = string
  default = null
}