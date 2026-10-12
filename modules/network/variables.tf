variable "name" {
  type = string

  description = "Name prefix for networking resources"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"

  description = "CIDR block for the VPC. Public and private /24 subnets are carved out of it."

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && tonumber(split("/", var.vpc_cidr)[1]) <= 20
    error_message = "vpc_cidr must be a valid CIDR block of /20 or larger."
  }
}

variable "az_count" {
  type    = number
  default = 2

  description = "Number of availability zones to span. The ALB requires at least 2."

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "nat_gateway_enabled" {
  type    = bool
  default = false

  description = "Use a managed NAT Gateway (~$33/month + data) instead of the free-tier eligible NAT instance."
}

variable "nat_instance_type" {
  type    = string
  default = "t2.micro"

  description = "Instance type for the NAT instance (ignored when nat_gateway_enabled = true)"
}
