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
  name              = "test"
  vpc_id            = "vpc-0123456789abcdef0"
  public_subnet_ids = ["subnet-0000000000000000a", "subnet-0000000000000000b"]
  targets = {
    ec2 = { target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test-ec2/0123456789abcdef" }
    ecs = { target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test-ecs/0123456789abcdef", weight = 3 }
  }
}

run "is_internet_facing_in_the_public_subnets" {
  command = plan

  assert {
    condition     = aws_lb.this.internal == false && toset(aws_lb.this.subnets) == toset(var.public_subnet_ids)
    error_message = "The load balancer must be internet-facing in the public subnets."
  }

  assert {
    condition     = aws_lb.this.drop_invalid_header_fields == true
    error_message = "The load balancer should drop invalid HTTP headers."
  }
}

run "forwards_to_every_target_by_weight" {
  command = plan

  assert {
    condition = {
      for tg in one(one(aws_lb_listener.http.default_action).forward).target_group : tg.arn => tg.weight
      } == {
      (var.targets.ec2.target_group_arn) = 1
      (var.targets.ecs.target_group_arn) = 3
    }
    error_message = "The listener must forward to every enabled target group with its weight."
  }
}

run "requires_at_least_one_target" {
  command = plan

  variables {
    targets = {}
  }

  expect_failures = [var.targets]
}
