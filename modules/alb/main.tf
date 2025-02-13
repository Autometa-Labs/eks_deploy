terraform {
  required_providers {
  }
}

locals {
  availability_zone_subnets = {
    for subnet in var.subnets : subnet.availability_zone => subnet.id...
  }
}

resource "aws_lb" "external_alb"{
  name               = var.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.alb_sg
  subnets            = [for subnet_ids in local.availability_zone_subnets : subnet_ids[0]]
  enable_deletion_protection = false
  enable_tls_version_and_cipher_suite_headers = true
}


resource "aws_lb_target_group" "external_alb_tg" {
  name        = "${var.alb_name}-tg"
  port        = var.lb_port
  protocol    = "HTTPS"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    protocol = "HTTPS"
    path     = "/"
    port     = "traffic-port"
    healthy_threshold = 3
    unhealthy_threshold = 2
    timeout =  5
    interval = 30
    matcher = 200
  }
}

resource "aws_lb_target_group_attachment" "external_alb_target_group_attachment" {
  count            = length(var.palo_alto_firewalls_instances)
  target_group_arn = aws_lb_target_group.external_alb_tg.arn
  target_id        = var.palo_alto_firewalls_instances[count.index]
  port             = var.lb_port
}

resource "aws_lb_listener" "external_alb_listener" {
  load_balancer_arn = aws_lb.external_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.external_alb_tg.arn
  }
}


# resource "aws_alb" "internal_alb" {
#     name               = var.alb_name
#     # availability_zones = var.availability_zones
#     subnets   =   [for subnet_ids in local.availability_zone_subnets : subnet_ids[0]]
#     connection_draining = false
#     internal = var.internal
#     dynamic "listener" {
#         for_each = var.ports
#         iterator = port
#         content {
#         instance_port     = port.value["instance_port"]
#         instance_protocol = port.value["instance_protocol"]
#         lb_port           = port.value["lb_port"]
#         lb_protocol       = port.value["lb_protocol"]
#         }
#     }
#     health_check {
#         healthy_threshold   = var.healthy_threshold
#         interval            = var.interval
#         target              = "${var.health_check_protocol}:${var.health_check_port}"
#         timeout             = var.timeout
#         unhealthy_threshold = var.unhealthy_threshold
#     }
# }