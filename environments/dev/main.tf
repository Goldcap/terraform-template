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

module "bastion" {
  source = "../../modules/bastion"

  name              = local.name
  vpc_id            = module.network.vpc_id
  vpc_cidr          = module.network.vpc_cidr
  subnet_id         = module.network.public_subnet_ids[0]
  instance_type     = var.instance_type
  key_name          = aws_key_pair.this.key_name
  ssh_allowed_cidrs = var.ssh_allowed_cidrs
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
