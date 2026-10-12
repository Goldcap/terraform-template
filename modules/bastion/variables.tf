variable "name" {
  type = string

  description = "Name prefix for bastion resources"
}

variable "vpc_id" {
  type = string

  description = "ID of the VPC the bastion is deployed into"
}

variable "vpc_cidr" {
  type = string

  description = "CIDR block of the VPC. The bastion may only reach instances inside it over SSH and HTTP."
}

variable "subnet_id" {
  type = string

  description = "ID of the public subnet for the bastion"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"

  description = "Bastion instance type"
}

variable "key_name" {
  type = string

  description = "Name of the EC2 key pair allowed to SSH to the bastion"
}

variable "ssh_allowed_cidrs" {
  type = list(string)

  description = "CIDR blocks allowed to SSH to the bastion - normally just your own IP as a /32"

  validation {
    condition     = length(var.ssh_allowed_cidrs) > 0 && alltrue([for cidr in var.ssh_allowed_cidrs : can(cidrhost(cidr, 0)) && cidr != "0.0.0.0/0"])
    error_message = "ssh_allowed_cidrs must contain valid CIDR blocks and must not include 0.0.0.0/0."
  }
}
