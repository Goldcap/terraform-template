# Environment-level tests: how the modules are wired together for dev.
# The AWS provider is mocked, so these run without credentials:
#   terraform init -backend=false && terraform test
#
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
  ssh_allowed_cidrs = ["203.0.113.10/32"]
  ssh_public_key    = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl"
  alarm_email       = "test@example.com"
}

run "bastion_only_accepts_ssh_from_the_trusted_ip" {
  command = plan

  assert {
    condition = alltrue([
      for rule in values(module.bastion.ingress_rules) :
      rule.from_port == 22 && rule.to_port == 22 && rule.cidr_ipv4 == "203.0.113.10/32"
    ]) && length(module.bastion.ingress_rules) == 1
    error_message = "The bastion must only accept SSH, and only from the trusted IP."
  }
}

run "rejects_ssh_from_anywhere" {
  command = plan

  variables {
    ssh_allowed_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.ssh_allowed_cidrs]
}

run "rejects_ssh_from_a_range" {
  command = plan

  variables {
    ssh_allowed_cidrs = ["203.0.113.0/24"]
  }

  expect_failures = [var.ssh_allowed_cidrs]
}

run "rejects_invalid_ssh_public_key" {
  command = plan

  variables {
    ssh_public_key = "not-a-key"
  }

  expect_failures = [var.ssh_public_key]
}

run "serves_from_ec2_and_ecs_by_default" {
  command = plan

  assert {
    condition     = length(module.web_asg) == 1 && length(module.web_ecs) == 1
    error_message = "Both the EC2 and ECS platforms should be enabled by default."
  }

  assert {
    condition     = toset(keys(local.platforms)) == toset(["ec2", "ecs"])
    error_message = "The load balancer should forward to both platforms."
  }
}

run "platforms_can_be_toggled_independently" {
  command = plan

  variables {
    enable_ec2 = false
  }

  assert {
    condition     = length(module.web_asg) == 0 && length(module.web_ecs) == 1 && toset(keys(local.platforms)) == toset(["ecs"])
    error_message = "Disabling EC2 should leave only the ECS platform behind the load balancer."
  }
}

run "rejects_disabling_every_platform" {
  command = plan

  variables {
    enable_ec2 = false
    enable_ecs = false
  }

  expect_failures = [var.enable_ecs]
}

run "rejects_weights_for_unknown_platforms" {
  command = plan

  variables {
    platform_weights = { lambda = 1 }
  }

  expect_failures = [var.platform_weights]
}
