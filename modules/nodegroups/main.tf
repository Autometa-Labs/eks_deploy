# =============================================
# NodeGroups
# =============================================
resource "aws_eks_node_group" "eks_nodegroup" {
  cluster_name    = var.cluster_name
  node_group_name = var.nodegroup_name
  node_role_arn   = aws_iam_role.eks_node_role.arn

  subnet_ids = var.subnets
  release_version = var.ssm_parameter
  launch_template {
    name = aws_launch_template.eks_launch_template.name
    version = 1
  }
  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  update_config {
    max_unavailable = 1
  }
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy_att,
    aws_iam_role_policy_attachment.eks_cni_policy_att,
    aws_iam_role_policy_attachment.eks_container_registry_read_only_att,
  ]
}
resource "aws_launch_template" "eks_launch_template" {
  instance_type          = var.instance_type
  name                   = var.launch_template
  update_default_version = true
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      encrypted = true
      volume_size = var.volume_size
    }
  }
 
#   user_data              = filebase64("${path.module}/instance_tagging.sh")
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name               = var.node_name
      type               =  var.ng_prefix
    }
  }
}