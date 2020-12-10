variable "tag_name" {
  description = "The name to tag AWS resources with"
  default     = "OpenVPN"
}

variable "instance_type" {
  description = "The instance type to use"
  default     = "t2.micro"
}

variable "instance_root_block_device_volume_size" {
  description = "The size of the root block device volume of the EC2 instance in GiB"
  default     = 8
}

variable "ec2_username" {
  description = "The user to connect to the EC2 as"
  default     = "ec2-user"
}

variable "openvpn_install_script_location" {
  description = "The location of an OpenVPN installation script compatible with https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh"
  default     = "https://raw.githubusercontent.com/dumrauf/openvpn-install/master/openvpn-install.sh"
}

variable "ovpn_users" {
  type        = list(string)
  description = "The list of users to automatically provision with OpenVPN access"
}