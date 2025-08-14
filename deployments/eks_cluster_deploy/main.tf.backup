# =============================================
# EKS Deployment
# =============================================

terraform {
  required_providers {
  }
}

provider "aws" {
  region = var.region[0]
}

# EKS Cluster module
module "eks_cluster" {
  source = "../../modules/eks"
  cluster_name = "${var.prefix}api-${var.cluster_prefix}"
  iam_role_name = "${var.prefix}cluster-role"
  vpc_name = data.aws_vpc.vpc.id
  cluster_policy = var.cluster_policy
  resource_controller_policy = var.resource_controller_policy
  subnets = data.aws_subnet.subnets.*.id
  aws_region = var.region[0]
}

# Nodegroup module
module "nodegroup" {
  for_each = { for obj in var.nodegroups : obj.ng_prefix => obj }
  source = "../../modules/nodegroups"
  cluster_name = module.eks_cluster.cluster_name
  desired_size = each.value.desired_size
  max_size = each.value.max_size
  min_size = each.value.min_size
  launch_template = "${var.prefix}${each.value.ng_prefix}-template-${var.cluster_prefix}"
  node_name = "${var.prefix}${each.value.ng_prefix}-node-${var.cluster_prefix}"
  nodegroup_name = "${var.prefix}${each.value.ng_prefix}-nodegroup-${var.cluster_prefix}"
  node_role_name = "${var.prefix}${each.value.ng_prefix}-node-role-${var.cluster_prefix}"
  instance_type = each.value.instance_type
  ssm_parameter = local.ssm_parameter
  worker_node_policy = var.worker_node_policy
  cni_policy = var.cni_policy
  container_registry_read_only_policy = var.container_registry_read_only_policy
  subnets = data.aws_subnet.subnets.*.id
  aws_region = var.region[0]
  ng_prefix = each.value.ng_prefix
  volume_size = each.value.volume_size
}

# ECR registry
module "ecr_registry" {
  source = "../../modules/ecr"
  ecr_registry_name = "${var.prefix}dev"
}

# EC2 instance module
# module "ec2_instance" {
#   source = "../../modules/ec2"
#   ami = var.ami
#   instance_name = "${var.prefix}mgmt-${var.cluster_prefix}"
#   key_name = var.key_name
#   instance_type = var.instance_type
#   subnet_id = data.aws_subnet.private_subnets[0].id
#   sg_name = "${var.prefix}sg"
#   vpc_id = data.aws_vpc.vpc.id
#   base_sg_id = "${length(data.aws_security_groups.base_sg.ids) > 0 ? data.aws_security_groups.base_sg.ids[0] : null}"
# }

# ALB module
# module "aws_alb" {
#   subnets = data.aws_subnet.public_subnets
#   alb_name = "${var.prefix}alb-${var.cluster_prefix}"
#   alb_sg = data.aws_security_group.external_alb_sg.*.id
#   lb_port = var.alb_port
#   vpc_id = data.aws_vpc.inb_vpc.id
#   palo_alto_firewalls_instances = data.aws_instance.palo_alto_firewalls_instances.*.id
#   ssl_policy = var.ssl_policy
#   certificate_arn = var.certificate_arn
#   source = "../../modules/alb"
# }

# # Route53 records
# module "records" {
#   for_each = { for obj in var.records : obj.name => obj }
#   source = "../../modules/records"
#   route53_zone_id = data.aws_route53_zone.zone_id.zone_id
#   record_name = each.value.name
#   record_type = each.value.type
#   record_ttl = each.value.ttl
#   elb_dns_name = "${var.elb_create ? module.aws_elb[0].dns_name : data.aws_elb.aws_elb[0].dns_name }"
# }