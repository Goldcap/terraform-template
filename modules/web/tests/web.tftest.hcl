# Plan-time unit tests. The AWS provider is mocked, so these run in CI on
# every pull request without credentials and without creating anything:
#   terraform init -backend=false && terraform test

# The random provider is not mocked: it runs locally without credentials, and
# mock providers do not support its ephemeral random_password.

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }

  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "ami-0123456789abcdef0"
    }
  }

  # IAM policy documents must be valid JSON for the resources that use them.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  name                      = "test"
  vpc_id                    = "vpc-0123456789abcdef0"
  public_subnet_ids         = ["subnet-0000000000000000a", "subnet-0000000000000000b"]
  private_subnet_ids        = ["subnet-0000000000000000c", "subnet-0000000000000000d"]
  bastion_security_group_id = "sg-0123456789abcdef0"
  key_name                  = "test"
}

run "web_servers_are_t2_micro_in_private_subnets" {
  command = plan

  assert {
    condition     = aws_launch_template.web.instance_type == "t2.micro"
    error_message = "Web servers must be t2.micro."
  }

  assert {
    condition     = toset(aws_autoscaling_group.web.vpc_zone_identifier) == toset(var.private_subnet_ids)
    error_message = "Web servers must launch in the private subnets."
  }

  assert {
    condition     = aws_lb.this.internal == false && toset(aws_lb.this.subnets) == toset(var.public_subnet_ids)
    error_message = "The load balancer must be internet-facing in the public subnets."
  }
}

run "autoscaling_group_scales_between_1_and_3_on_cpu" {
  command = plan

  assert {
    condition     = aws_autoscaling_group.web.min_size == 1 && aws_autoscaling_group.web.max_size == 3
    error_message = "The Auto Scaling Group must scale between 1 and 3 instances."
  }

  assert {
    condition     = aws_autoscaling_policy.cpu_target_tracking.target_tracking_configuration[0].predefined_metric_specification[0].predefined_metric_type == "ASGAverageCPUUtilization"
    error_message = "Scaling must be driven by average CPU utilization."
  }

  assert {
    condition     = aws_autoscaling_group.web.health_check_type == "ELB"
    error_message = "The Auto Scaling Group must use load balancer health checks."
  }
}

run "web_servers_only_accept_traffic_from_alb_and_bastion" {
  command = plan

  assert {
    condition = alltrue([
      aws_vpc_security_group_ingress_rule.web_http_from_alb.cidr_ipv4 == null,
      aws_vpc_security_group_ingress_rule.web_http_from_bastion.cidr_ipv4 == null,
      aws_vpc_security_group_ingress_rule.web_ssh_from_bastion.cidr_ipv4 == null,
    ])
    error_message = "Web server ingress must reference security groups, never CIDR blocks."
  }

  assert {
    condition = alltrue([
      aws_vpc_security_group_ingress_rule.web_http_from_bastion.referenced_security_group_id == var.bastion_security_group_id,
      aws_vpc_security_group_ingress_rule.web_http_from_bastion.from_port == 80,
      aws_vpc_security_group_ingress_rule.web_ssh_from_bastion.referenced_security_group_id == var.bastion_security_group_id,
      aws_vpc_security_group_ingress_rule.web_ssh_from_bastion.from_port == 22,
      aws_vpc_security_group_ingress_rule.web_http_from_alb.from_port == 80,
    ])
    error_message = "Web servers must accept HTTP from the ALB and bastion, and SSH from the bastion only."
  }
}

run "instances_are_hardened" {
  command = plan

  assert {
    condition     = aws_launch_template.web.metadata_options[0].http_tokens == "required"
    error_message = "Web servers must require IMDSv2."
  }

  assert {
    condition     = aws_launch_template.web.block_device_mappings[0].ebs[0].encrypted == "true"
    error_message = "Web server volumes must be encrypted."
  }

  assert {
    condition     = aws_launch_template.web.monitoring[0].enabled == false
    error_message = "Detailed monitoring is billed - basic monitoring keeps the web tier in the free tier."
  }
}

run "admin_password_is_never_stored_in_state" {
  command = plan

  assert {
    condition     = aws_secretsmanager_secret_version.admin.secret_string == null
    error_message = "The admin password must be written through the write-only attribute only."
  }
}
