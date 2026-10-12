data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  azs = slice(sort(data.aws_availability_zones.available.names), 0, var.az_count)

  #                    10.0.0.0/24, 10.0.1.0/24, ...
  public_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]
  #                    10.0.10.0/24, 10.0.11.0/24, ...
  private_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 10)]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = var.name
  cidr = var.vpc_cidr

  azs             = local.azs
  public_subnets  = local.public_subnet_cidrs
  private_subnets = local.private_subnet_cidrs

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Instances only get a public IP when they explicitly ask for one (bastion, NAT).
  map_public_ip_on_launch = false

  # A single NAT (gateway or instance) keeps cost down. It is a single point of
  # failure for outbound traffic from private subnets - see README.
  enable_nat_gateway = var.nat_gateway_enabled
  single_nat_gateway = true

  # Strip all rules from the default security group so nothing uses it by accident.
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  public_subnet_tags  = { Tier = "public" }
  private_subnet_tags = { Tier = "private" }
}

# Gateway endpoints are free and keep S3 traffic (e.g. package repositories)
# off the NAT.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    module.vpc.private_route_table_ids,
    module.vpc.public_route_table_ids
  )

  tags = { Name = "${var.name}-s3" }
}
