variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
  default     = null
}

variable "iam_role_name" {
  type        = string
  description = "IAM role name for EKS cluster"
  default     = null
}

variable "cluster_policy" {
  type        = string
  description = "IAM policy for EKS cluster"
  default     = null
}

variable "resource_controller_policy" {
  type        = string
  description = "Controller policy for EKS cluster"
  default     = null
}

variable "subnets" {type = list(any)}

variable "vpc_name" {
  type        = string
  description = "Name of VPC"
  default     = null
}

variable "aws_region" {
  description = "Region where VPC is deployed"
  type        = string
  default     = null
}