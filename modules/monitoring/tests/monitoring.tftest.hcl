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
  name                    = "test"
  autoscaling_group_name  = "test-web"
  alb_arn_suffix          = "app/test-alb/0123456789abcdef"
  target_group_arn_suffix = "targetgroup/test-web/0123456789abcdef"
  alarm_email             = "test@example.com"
}

run "cpu_alarm_notifies_sns_above_70_percent" {
  command = plan

  assert {
    condition     = aws_cloudwatch_metric_alarm.cpu_high.threshold == 70 && aws_cloudwatch_metric_alarm.cpu_high.comparison_operator == "GreaterThanThreshold"
    error_message = "The CPU alarm must trigger above 70%."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.cpu_high.metric_name == "CPUUtilization" && aws_cloudwatch_metric_alarm.cpu_high.dimensions["AutoScalingGroupName"] == "test-web"
    error_message = "The CPU alarm must watch the Auto Scaling Group's CPUUtilization."
  }

  assert {
    condition     = aws_sns_topic_subscription.email.protocol == "email" && aws_sns_topic_subscription.email.endpoint == "test@example.com"
    error_message = "Alarms must notify the configured email address."
  }
}

run "memory_is_monitored" {
  command = plan

  assert {
    condition     = aws_cloudwatch_metric_alarm.memory_high.metric_name == "mem_used_percent" && aws_cloudwatch_metric_alarm.memory_high.namespace == "CWAgent"
    error_message = "Memory must be monitored via the CloudWatch agent metric."
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
