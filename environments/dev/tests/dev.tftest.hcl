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

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:sts::123456789012:assumed-role/developer/session"
    }
  }

  mock_data "aws_iam_session_context" {
    defaults = {
      issuer_arn = "arn:aws:iam::123456789012:role/developer"
    }
  }

  mock_data "aws_eks_addon_version" {
    defaults = {
      version = "v1.0.0-eksbuild.1"
    }
  }

  mock_resource "aws_eks_cluster" {
    defaults = {
      vpc_config = [{ cluster_security_group_id = "sg-0eeeeeeeeeeeeeeee" }]
    }
  }
}

mock_provider "helm" {}

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
    condition     = length(module.web_eks) == 0
    error_message = "EKS should be off by default because of its control plane cost."
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

run "eks_can_be_enabled_alongside_the_others" {
  command = plan

  variables {
    enable_eks = true
  }

  assert {
    condition     = length(module.web_eks) == 1
    error_message = "enable_eks = true should add the EKS platform."
  }
}

run "eks_creator_admin_only_when_not_already_listed" {
  command = plan

  variables {
    enable_eks = true
  }

  assert {
    condition     = local.permissions_boundary_arn == "arn:aws:iam::123456789012:policy/hello-world-workload-boundary"
    error_message = "Roles must carry the bootstrap stack's workload boundary."
  }

  # A developer outside the explicit list gets EKS's automatic creator entry.
  assert {
    condition     = !contains(local.eks_explicit_principals, data.aws_iam_session_context.current.issuer_arn)
    error_message = "A developer who isn't listed should get the cluster creator's admin entry."
  }

  # In CI the plan role computes the plan and the apply role applies it, so
  # neither may also get the automatic entry, or it collides with theirs.
  assert {
    condition = alltrue([
      for arn in ["arn:aws:iam::123456789012:role/hello-world-github-plan", "arn:aws:iam::123456789012:role/hello-world-github-apply"] :
      contains(local.eks_explicit_principals, arn)
    ])
    error_message = "Both CI roles must be treated as already having cluster access."
  }
}

run "rejects_disabling_every_platform" {
  command = plan

  variables {
    enable_ec2 = false
    enable_ecs = false
  }

  expect_failures = [var.enable_eks]
}

run "rejects_weights_for_unknown_platforms" {
  command = plan

  variables {
    platform_weights = { lambda = 1 }
  }

  expect_failures = [var.platform_weights]
}

run "rejects_an_assume_role_arn_that_is_not_a_role" {
  command = plan

  variables {
    assume_role_arn = "arn:aws:iam::123456789012:user/someone"
  }

  expect_failures = [var.assume_role_arn]
}

run "rejects_a_project_name_reserved_by_ecs" {
  command = plan

  variables {
    project = "ecs-demo"
  }

  expect_failures = [var.project]
}
