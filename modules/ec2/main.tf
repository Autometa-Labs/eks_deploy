
resource "aws_security_group" "security_group" {
  name        = var.sg_name
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = [22,80,443]
    iterator = port
    content {
      description      = "TLS from VPC"
      from_port        = port.value
      to_port          = port.value
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }
  }

  dynamic "egress" {
    for_each = [0]
    iterator = port
    content {
      from_port        = port.value
      to_port          = port.value
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }
  tags = {
    Name = var.sg_name
  }
}

resource "aws_instance" "sst_remote" {
    ami = var.ami
    instance_type = var.instance_type
    key_name = var.key_name
    subnet_id = var.subnet_id
    associate_public_ip_address = true
    vpc_security_group_ids = "${var.base_sg_id != null ? [var.base_sg_id, aws_security_group.security_group.id] : [aws_security_group.security_group.id]}"
    tags = {
      Name = var.instance_name
      type =  "mgmt"
  }
}