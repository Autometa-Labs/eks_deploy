variable "instance_name" {
  type = string
  description = "ec2 instance name"
  default = null
}

variable "key_name" {
  type = string
  description = "key pair name for login"
  default = null
}

variable "instance_type" {
  type = string
  description = "instance type for ec2"
  default = null
}

variable "subnet_id" {
  type        = string
  description = "subnet id"
  default     = null
}

variable "sg_name" {
  type = string
  description = "security group name"
  default = null
}

variable "vpc_id" {
  type = string
  description = "vpc id in which you want to deploy ec2 instance"
  default = null
}

variable "base_sg_id" {
  type = string
  description = "base security group id"
  default = null
}

variable "ami" {
  type = string
  description = "aws image ami id"
  default = null
}






