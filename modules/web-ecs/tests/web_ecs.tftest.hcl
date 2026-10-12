# Plan-time unit tests. The AWS provider is mocked, so these run in CI on
# every pull request without credentials and without creating anything:
#   terraform init -backend=false && terraform test

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
  private_subnet_ids        = ["subnet-0000000000000000c", "subnet-0000000000000000d"]
  alb_security_group_id     = "sg-0aaaaaaaaaaaaaaaa"
  bastion_security_group_id = "sg-0123456789abcdef0"
  key_name                  = "test"
  admin_secret_arn          = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test-admin-AbCdEf"
}

run "runs_on_t2_micro_container_instances_in_private_subnets" {
  command = plan

  assert {
    condition     = aws_launch_template.ecs.instance_type == "t2.micro"
    error_message = "Container instances must be t2.micro."
  }

  assert {
    condition     = toset(aws_autoscaling_group.ecs.vpc_zone_identifier) == toset(var.private_subnet_ids)
    error_message = "Container instances must run in the private subnets."
  }

  assert {
    condition     = aws_launch_template.ecs.metadata_options[0].http_tokens == "required" && aws_launch_template.ecs.metadata_options[0].http_put_response_hop_limit == 1
    error_message = "IMDSv2 must be required, with a hop limit that keeps containers away from instance credentials."
  }

  assert {
    condition     = aws_launch_template.ecs.block_device_mappings[0].ebs[0].encrypted == "true"
    error_message = "Container instance volumes must be encrypted."
  }
}

run "service_scales_between_1_and_3_tasks_on_cpu" {
  command = plan

  assert {
    condition     = aws_appautoscaling_target.nginx.min_capacity == 1 && aws_appautoscaling_target.nginx.max_capacity == 3
    error_message = "The service must scale between 1 and 3 tasks."
  }

  assert {
    condition     = aws_appautoscaling_policy.cpu_target_tracking.target_tracking_scaling_policy_configuration[0].predefined_metric_specification[0].predefined_metric_type == "ECSServiceAverageCPUUtilization"
    error_message = "Service scaling must be driven by average CPU utilization."
  }

  assert {
    condition     = aws_autoscaling_group.ecs.min_size == 1 && aws_autoscaling_group.ecs.max_size == 3
    error_message = "The capacity provider's Auto Scaling Group must hold 1 to 3 instances."
  }

  assert {
    condition     = aws_ecs_service.nginx.deployment_circuit_breaker[0].rollback == true
    error_message = "Failed deployments must roll back automatically."
  }
}

run "admin_credentials_come_from_secrets_manager" {
  command = plan

  assert {
    condition = toset([for s in jsondecode(aws_ecs_task_definition.nginx.container_definitions)[0].secrets : s.valueFrom]) == toset([
      "${var.admin_secret_arn}:username::",
      "${var.admin_secret_arn}:password::",
    ])
    error_message = "The task definition must inject the admin credentials from Secrets Manager."
  }

  assert {
    condition     = !strcontains(aws_ecs_task_definition.nginx.container_definitions, "\"environment\"")
    error_message = "No plaintext environment variables should be set on the container."
  }
}

run "nginx_gets_no_aws_credentials" {
  command = plan

  assert {
    condition     = aws_ecs_task_definition.nginx.task_role_arn == null
    error_message = "The nginx container makes no AWS calls and must not get a task role."
  }
}

run "instances_only_accept_task_ports_from_the_alb" {
  command = plan

  assert {
    condition = alltrue([
      aws_vpc_security_group_ingress_rule.tasks_from_alb.referenced_security_group_id == var.alb_security_group_id,
      aws_vpc_security_group_ingress_rule.tasks_from_alb.cidr_ipv4 == null,
      aws_vpc_security_group_ingress_rule.ssh_from_bastion.referenced_security_group_id == var.bastion_security_group_id,
    ])
    error_message = "Container instances must only accept task traffic from the ALB and SSH from the bastion."
  }
}
