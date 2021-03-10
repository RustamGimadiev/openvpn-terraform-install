data "aws_ami" "amazon_linux_2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "block-device-mapping.volume-type"
    values = ["gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}

resource "tls_private_key" "openvpn" {
  algorithm = "RSA"
}

resource "local_file" "openvpn" {
  filename        = "${path.root}/openvpn.pem"
  file_permission = "0600"
  content         = tls_private_key.openvpn.private_key_pem
}

module "key_pair" {
  source  = "terraform-aws-modules/key-pair/aws"
  version = "0.6.0"

  key_name   = "openvpn-ssh-key"
  public_key = tls_private_key.openvpn.public_key_openssh
}

variable "openvpn_ami" {
  default = ""
}

resource "aws_instance" "openvpn" {
  ami                         = coalesce(var.openvpn_ami, data.aws_ami.amazon_linux_2.id)
  associate_public_ip_address = true
  instance_type               = var.instance_type
  key_name                    = module.key_pair.this_key_pair_key_name
  subnet_id                   = element(tolist(local.subnet_ids), 1)

  vpc_security_group_ids = [
    aws_security_group.openvpn.id,
    aws_security_group.ssh_from_local.id,
  ]

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.instance_root_block_device_volume_size
    delete_on_termination = true
  }

  tags = {
    Name        = var.tag_name
    Provisioner = "Terraform"
  }

  lifecycle {
    ignore_changes = [
      ami,
    ]
  }
}

resource "null_resource" "openvpn_bootstrap" {
  connection {
    type        = "ssh"
    host        = aws_instance.openvpn.public_ip
    user        = var.ec2_username
    port        = "22"
    private_key = tls_private_key.openvpn.private_key_pem
    agent       = false
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "curl -O ${var.openvpn_install_script_location}",
      "chmod +x openvpn-install.sh",
      <<EOT
      sudo AUTO_INSTALL=y \
           APPROVE_IP=${aws_instance.openvpn.public_ip} \
           ENDPOINT=${aws_instance.openvpn.public_dns} \
           ./openvpn-install.sh
      
EOT
      ,
    ]
  }
}

resource "null_resource" "openvpn_update_users_script" {
  depends_on = [null_resource.openvpn_bootstrap]

  triggers = {
    ovpn_users = join(" ", var.ovpn_users)
  }

  connection {
    type        = "ssh"
    host        = aws_instance.openvpn.public_ip
    user        = var.ec2_username
    port        = "22"
    private_key = tls_private_key.openvpn.private_key_pem
    agent       = false
  }

  provisioner "file" {
    source      = "${path.module}/scripts/update_users.sh"
    destination = "/home/${var.ec2_username}/update_users.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~${var.ec2_username}/update_users.sh",
      "sudo ~${var.ec2_username}/update_users.sh ${join(" ", var.ovpn_users)}",
    ]
  }
}

resource "null_resource" "openvpn_download_configurations" {
  depends_on = [null_resource.openvpn_update_users_script]

  triggers = {
    ovpn_users = join(" ", var.ovpn_users)
  }

  provisioner "local-exec" {
    command = <<EOT
    scp -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -i ${path.root}/openvpn.pem ${var.ec2_username}@${aws_instance.openvpn.public_ip}:/home/${var.ec2_username}/*.ovpn ${path.root}
    
EOT

  }
}
