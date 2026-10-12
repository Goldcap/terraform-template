locals {
  name = "${var.project}-${var.environment}"
}

module "network" {
  source = "../../modules/network"

  name                = local.name
  vpc_cidr            = var.vpc_cidr
  nat_gateway_enabled = var.nat_gateway_enabled
  nat_instance_type   = var.instance_type
}

resource "aws_key_pair" "this" {
  key_name   = local.name
  public_key = var.ssh_public_key
}

# The bastion host is the only SSH entry point: SSH in from trusted IPs only,
# SSH/HTTP out to instances inside the VPC.
module "bastion" {
  source = "../../modules/ec2"

  name          = "${local.name}-bastion"
  description   = "Bastion host: SSH in from trusted IPs, SSH/HTTP out to the VPC"
  vpc_id        = module.network.vpc_id
  subnet_id     = module.network.public_subnet_ids[0]
  instance_type = var.instance_type
  key_name      = aws_key_pair.this.key_name

  associate_public_ip_address = true

  # Keyed by position rather than by CIDR so the trusted IP doesn't appear in
  # resource addresses (and therefore in public CI logs).
  ingress_rules = {
    for index, cidr in var.ssh_allowed_cidrs : "ssh-${index}" => {
      description = "SSH from trusted IP"
      from_port   = 22
      to_port     = 22
      cidr_ipv4   = cidr
    }
  }

  # Scoped to the VPC rather than to the web tier's security groups, which
  # avoids a dependency cycle. The web tiers only admit traffic from the
  # bastion's security group, so the effective path is the same.
  egress_rules = {
    ssh-to-vpc = {
      description = "Port 22 to instances in the VPC"
      from_port   = 22
      to_port     = 22
      cidr_ipv4   = module.network.vpc_cidr
    }
    http-to-vpc = {
      description = "Port 80 to instances in the VPC"
      from_port   = 80
      to_port     = 80
      cidr_ipv4   = module.network.vpc_cidr
    }
    https = {
      description = "HTTPS for OS updates and the AWS CLI"
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  iam_policy_json = data.aws_iam_policy_document.bastion.json
}

# The bastion only needs to look up the private IPs of the web servers.
# ec2:DescribeInstances does not support resource-level restrictions.
data "aws_iam_policy_document" "bastion" {
  statement {
    sid       = "DiscoverInstances"
    effect    = "Allow"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }
}

module "web" {
  source = "../../modules/web"

  name                      = local.name
  vpc_id                    = module.network.vpc_id
  public_subnet_ids         = module.network.public_subnet_ids
  private_subnet_ids        = module.network.private_subnet_ids
  bastion_security_group_id = module.bastion.security_group_id
  key_name                  = aws_key_pair.this.key_name
  instance_type             = var.instance_type
  min_size                  = var.web_min_size
  max_size                  = var.web_max_size
  cpu_target_utilization    = var.cpu_target_utilization
}

module "monitoring" {
  source = "../../modules/monitoring"

  name                    = local.name
  autoscaling_group_name  = module.web.autoscaling_group_name
  alb_arn_suffix          = module.web.alb_arn_suffix
  target_group_arn_suffix = module.web.target_group_arn_suffix
  alarm_email             = var.alarm_email
  cpu_alarm_threshold     = var.cpu_alarm_threshold
  monthly_budget_usd      = var.monthly_budget_usd
}
