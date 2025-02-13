variable "alb_name" {
  type = string
  default = null
}

variable "alb_sg" {
  type = list(any)
  default = ["sg-0c190c13a680d78fa"]
}

variable "subnets" {
  type = list(any)
  default = null
}

variable "lb_port" {
  default = 8443
}

variable "vpc_id" {
  default = "vpc-09bff6bb60878ae9a"
}

variable "palo_alto_firewalls_instances" {
  type = list(any)
  default = ["i-0d88238319a6e5ca5", "i-0bd1dea21e7e3e6d9"]
}

variable "ssl_policy" {
  type = string
  default = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

variable "certificate_arn" {
  type = string
  default = "arn:aws:acm:us-east-1:343866166964:certificate/1d4a12f9-aace-4b48-beb3-a7a7e342417d"
}