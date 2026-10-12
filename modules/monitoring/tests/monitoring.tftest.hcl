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
  name           = "test"
  alb_arn_suffix = "app/test-alb/0123456789abcdef"
  alarm_email    = "test@example.com"

  autoscaling_groups = {
    ec2 = { name = "test-web", has_memory_metrics = true }
  }
  ecs_services = {
    ecs = { cluster_name = "test-ecs", service_name = "test-nginx" }
  }
  target_groups = {
    ec2 = "targetgroup/test-web/0123456789abcdef"
    ecs = "targetgroup/test-ecs/0123456789abcdef"
  }
}

run "every_platform_has_a_cpu_alarm_above_70_percent" {
  command = plan

  assert {
    condition = alltrue([
      for alarm in aws_cloudwatch_metric_alarm.cpu_high :
      alarm.threshold == 70 && alarm.comparison_operator == "GreaterThanThreshold" && alarm.metric_name == "CPUUtilization"
    ]) && keys(aws_cloudwatch_metric_alarm.cpu_high) == ["ec2", "ecs"]
    error_message = "Every platform must have a CPU alarm that triggers above 70%."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.cpu_high["ec2"].namespace == "AWS/EC2" && aws_cloudwatch_metric_alarm.cpu_high["ec2"].dimensions["AutoScalingGroupName"] == "test-web"
    error_message = "The EC2 CPU alarm must watch the Auto Scaling Group's CPUUtilization."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.cpu_high["ecs"].namespace == "AWS/ECS" && aws_cloudwatch_metric_alarm.cpu_high["ecs"].dimensions["ServiceName"] == "test-nginx"
    error_message = "The ECS CPU alarm must watch the service's CPUUtilization."
  }

  assert {
    condition     = aws_sns_topic_subscription.email.protocol == "email" && aws_sns_topic_subscription.email.endpoint == "test@example.com"
    error_message = "Alarms must notify the configured email address."
  }
}

run "memory_is_monitored_for_every_platform" {
  command = plan

  assert {
    condition     = aws_cloudwatch_metric_alarm.memory_high["ec2"].metric_name == "mem_used_percent" && aws_cloudwatch_metric_alarm.memory_high["ec2"].namespace == "CWAgent"
    error_message = "EC2 memory must be monitored via the CloudWatch agent metric."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.memory_high["ecs"].metric_name == "MemoryUtilization" && aws_cloudwatch_metric_alarm.memory_high["ecs"].namespace == "AWS/ECS"
    error_message = "ECS memory must be monitored via the service metric."
  }
}

run "every_target_group_has_a_health_alarm" {
  command = plan

  assert {
    condition     = keys(aws_cloudwatch_metric_alarm.no_healthy_hosts) == ["ec2", "ecs"]
    error_message = "Every platform's target group must have a no-healthy-hosts alarm."
  }
}

run "budget_can_be_disabled" {
  command = plan

  variables {
    monthly_budget_usd = null
  }

  assert {
    condition     = length(aws_budgets_budget.monthly) == 0
    error_message = "Setting monthly_budget_usd = null should disable the budget."
  }
}

run "rejects_invalid_email" {
  command = plan

  variables {
    alarm_email = "not-an-email"
  }

  expect_failures = [var.alarm_email]
}
