resource "aws_security_group_rule" "allow_internal_traffic_80" {
  type                    = "ingress"
  security_group_id       = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  from_port               = 80
  to_port                 = 80
  protocol                = "tcp"
  cidr_blocks             = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_internal_traffic_443" {
  type                    = "ingress"
  security_group_id       = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  from_port               = 443
  to_port                 = 443
  protocol                = "tcp"
  cidr_blocks             = ["0.0.0.0/0"]
}

# resource "aws_security_group_rule" "allow_internal_traffic_9090" {
#   type              = "ingress"
#   security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
#   from_port         = 9090
#   to_port           = 9090
#   protocol          = "tcp"
#   cidr_blocks       = ["0.0.0.0/0", "0.0.0.0/0"]
# }

# resource "aws_security_group_rule" "allow_internal_traffic_1521" {
#   type              = "ingress"
#   security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
#   from_port         = 1521
#   to_port           = 1521
#   protocol          = "tcp"
#   cidr_blocks       = ["10.247.0.0/24", "10.248.0.0/24"]
# }