# resource "aws_security_group" "eks_node_sg" {
#   name        = "${var.cluster_name}-node-sg"
#   description = "Security group for EKS nodes"
#   vpc_id      = var.vpc_id

#   ingress {
#     from_port   = 8080
#     to_port     = 8080
#     protocol    = "tcp"
#     cidr_blocks = ["10.247.0.0/24","10.248.0.0/24"]
#   }

#   ingress {
#     from_port   = 9090
#     to_port     = 9090
#     protocol    = "tcp"
#     cidr_blocks = ["10.247.0.0/24","10.248.0.0/24"]
#   }

#   ingress {
#     from_port   = 1521
#     to_port     = 1521
#     protocol    = "tcp"
#     cidr_blocks = ["10.2.4.10/32"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "${var.cluster_name}-node-sg"
#   }
# }

# resource "aws_security_group_rule" "allow_all_traffic" {
#   type              = "ingress"
#   security_group_id = aws_security_group.eks_node_sg.id
#   from_port         = 0
#   to_port           = 0
#   protocol          = "-1"
#   source_security_group_id = var.eks_cluster_sg_id
# }