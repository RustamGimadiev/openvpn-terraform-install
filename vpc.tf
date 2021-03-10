resource "aws_default_vpc" "openvpn" {
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = var.tag_name
    Provisioner = "Terraform"
  }
}

data "aws_subnet_ids" "openvpn" {
  vpc_id = local.vpc_id
}

locals {
  vpc_id     = var.vpc_id == "" ? aws_default_vpc.openvpn.id : var.vpc_id
  subnet_ids = var.subnet_ids == [] ? data.aws_subnet_ids.openvpn.ids : var.subnet_ids
}

resource "aws_security_group" "openvpn" {
  name        = "openvpn"
  description = "Allow inbound UDP access to OpenVPN and unrestricted egress"

  vpc_id = local.vpc_id

  tags = {
    Name        = var.tag_name
    Provisioner = "Terraform"
  }

  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ssh_from_local" {
  name        = "ssh-from-local"
  description = "Allow SSH access only from local machine"

  vpc_id = local.vpc_id

  tags = {
    Name        = var.tag_name
    Provisioner = "Terraform"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.local_ip_address]
  }
}

