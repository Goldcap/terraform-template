locals {
  name = "${var.project}-${var.environment}"

  # Created by environments/bootstrap. The CI apply role may only create
  # roles that carry it.
  permissions_boundary_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.project}-workload-boundary"
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
#
# Kept because the exercise asks for a bastion. In production this - and SSH
# entirely - would be disabled in favor of SSM Session Manager: no inbound
# ports, IAM-controlled and logged sessions, no keys (see README).
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

  permissions_boundary = local.permissions_boundary_arn
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

# --- Web platforms -------------------------------------------------------------
# Each platform serves the same Hello World site. Any combination can be
# enabled; the load balancer splits traffic between them by weight.

module "web_asg" {
  source = "../../modules/web-asg"
  count  = var.enable_ec2 ? 1 : 0

  name                      = local.name
  vpc_id                    = module.network.vpc_id
  private_subnet_ids        = module.network.private_subnet_ids
  alb_security_group_id     = module.alb.security_group_id
  bastion_security_group_id = module.bastion.security_group_id
  key_name                  = aws_key_pair.this.key_name
  admin_secret_arn          = local.admin_secret_arn
  instance_type             = var.instance_type
  min_size                  = var.web_min_size
  max_size                  = var.web_max_size
  cpu_target_utilization    = var.cpu_target_utilization

  permissions_boundary = local.permissions_boundary_arn
}

module "web_ecs" {
  source = "../../modules/web-ecs"
  count  = var.enable_ecs ? 1 : 0

  name                      = local.name
  vpc_id                    = module.network.vpc_id
  private_subnet_ids        = module.network.private_subnet_ids
  alb_security_group_id     = module.alb.security_group_id
  bastion_security_group_id = module.bastion.security_group_id
  key_name                  = aws_key_pair.this.key_name
  admin_secret_arn          = local.admin_secret_arn
  instance_type             = var.instance_type
  min_size                  = var.web_min_size
  max_size                  = var.web_max_size
  cpu_target_utilization    = var.cpu_target_utilization

  # Keep the NAT path until the service has drained (see modules/web-ecs).
  egress_dependency = module.network.egress_id

  permissions_boundary = local.permissions_boundary_arn
}

data "aws_caller_identity" "current" {}

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

locals {
  # CI roles created by environments/bootstrap (same naming convention).
  ci_apply_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project}-github-apply"
  ci_plan_role_arn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project}-github-plan"
}

module "web_eks" {
  source = "../../modules/web-eks"
  count  = var.enable_eks ? 1 : 0

  name                  = local.name
  vpc_id                = module.network.vpc_id
  private_subnet_ids    = module.network.private_subnet_ids
  alb_security_group_id = module.alb.security_group_id
  admin_secret_arn      = local.admin_secret_arn
  egress_dependency     = module.network.egress_id
  node_min_size         = var.web_min_size
  node_max_size         = var.web_max_size

  # Per-environment Helm overrides for the hello-world chart.
  app_values = [file("${path.module}/helm/hello-world.yaml")]

  # CI applies as cluster admin and plans with read-only access. Whoever
  # creates the cluster gets admin too, unless that's the CI apply role,
  # which already has an access entry.
  cluster_admin_principal_arns    = distinct(concat([local.ci_apply_role_arn], var.eks_admin_principal_arns))
  cluster_viewer_principal_arns   = [local.ci_plan_role_arn]
  bootstrap_cluster_creator_admin = data.aws_iam_session_context.current.issuer_arn != local.ci_apply_role_arn

  permissions_boundary = local.permissions_boundary_arn
}

locals {
  # Enabled platforms and what the load balancer and monitoring need from each.
  platforms = merge(
    var.enable_ec2 ? {
      ec2 = {
        target_group_arn        = module.web_asg[0].target_group_arn
        target_group_arn_suffix = module.web_asg[0].target_group_arn_suffix
      }
    } : {},
    var.enable_ecs ? {
      ecs = {
        target_group_arn        = module.web_ecs[0].target_group_arn
        target_group_arn_suffix = module.web_ecs[0].target_group_arn_suffix
      }
    } : {},
    var.enable_eks ? {
      eks = {
        target_group_arn        = module.web_eks[0].target_group_arn
        target_group_arn_suffix = module.web_eks[0].target_group_arn_suffix
      }
    } : {}
  )
}

module "alb" {
  source = "../../modules/alb"

  name              = local.name
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids

  targets = {
    for platform, config in local.platforms : platform => {
      target_group_arn = config.target_group_arn
      weight           = lookup(var.platform_weights, platform, 1)
    }
  }
}

module "monitoring" {
  source = "../../modules/monitoring"

  name           = local.name
  alb_arn_suffix = module.alb.arn_suffix
  alarm_email    = var.alarm_email

  # EKS CPU is watched on the node group; pod-level metrics would need
  # Container Insights, which is billed.
  autoscaling_groups = merge(
    var.enable_ec2 ? {
      ec2 = { name = module.web_asg[0].autoscaling_group_name, has_memory_metrics = true }
    } : {},
    var.enable_eks ? {
      eks = { name = module.web_eks[0].node_autoscaling_group_name }
    } : {}
  )

  ecs_services = var.enable_ecs ? {
    ecs = { cluster_name = module.web_ecs[0].cluster_name, service_name = module.web_ecs[0].service_name }
  } : {}

  target_groups = { for platform, config in local.platforms : platform => config.target_group_arn_suffix }

  cpu_alarm_threshold = var.cpu_alarm_threshold
  monthly_budget_usd  = var.monthly_budget_usd
}
