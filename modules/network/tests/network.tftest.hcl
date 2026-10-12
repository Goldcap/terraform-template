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
  name = "test"
}

run "creates_public_and_private_subnets_in_two_azs" {
  command = plan

  assert {
    condition     = length(module.vpc.private_subnets) == 2 && length(module.vpc.public_subnets) == 2
    error_message = "The VPC must have a public and a private subnet in each of two AZs."
  }

  assert {
    condition     = local.private_subnet_cidrs == ["10.0.10.0/24", "10.0.11.0/24"]
    error_message = "Private subnets should be carved from the VPC CIDR as /24s."
  }
}

run "uses_a_nat_instance_by_default" {
  command = plan

  assert {
    condition     = length(module.nat_instance) == 1 && length(aws_route.private_via_nat_instance) == 1
    error_message = "By default a free-tier NAT instance should provide egress for the private subnets."
  }
}

run "nat_instance_only_accepts_web_ports_from_private_subnets" {
  command = plan

  assert {
    condition = alltrue([
      for rule in values(module.nat_instance[0].ingress_rules) :
      contains(local.private_subnet_cidrs, rule.cidr_ipv4) && contains([80, 443], rule.from_port)
    ])
    error_message = "The NAT instance must only accept HTTP/HTTPS from the private subnets."
  }
}

run "can_switch_to_a_nat_gateway" {
  command = plan

  variables {
    nat_gateway_enabled = true
  }

  assert {
    condition     = length(module.nat_instance) == 0 && length(aws_route.private_via_nat_instance) == 0
    error_message = "nat_gateway_enabled = true should remove the NAT instance and its routes."
  }
}
