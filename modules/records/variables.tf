variable "route53_zone_id" {
  type = string
  default = null
}

variable "record_name" {
  type = string
  default = null
}

variable "record_type" {
  type = string
  default = null
}

variable "record_ttl" {
  type = number
  default = null
}

variable "elb_dns_name" {
  type = string
  default = null
}