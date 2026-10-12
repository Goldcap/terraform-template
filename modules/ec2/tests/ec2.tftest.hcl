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
  name        = "test-instance"
  description = "Test instance"
  vpc_id      = "vpc-0123456789abcdef0"
  subnet_id   = "subnet-0123456789abcdef0"
}

run "is_a_hardened_t2_micro_by_default" {
  command = plan

  assert {
    condition     = aws_instance.this.instance_type == "t2.micro"
    error_message = "Instances should default to the free-tier t2.micro."
  }

  assert {
    condition     = aws_instance.this.metadata_options[0].http_tokens == "required"
    error_message = "Instances must require IMDSv2."
  }

  assert {
    condition     = aws_instance.this.root_block_device[0].encrypted == true
    error_message = "Root volumes must be encrypted."
  }

  assert {
    condition     = aws_instance.this.associate_public_ip_address == false
    error_message = "Instances must not get a public IP unless asked to."
  }

  assert {
    condition     = aws_instance.this.ami == "ami-0123456789abcdef0"
    error_message = "The AMI should default to the latest Amazon Linux 2023 from SSM."
  }
}

run "has_no_iam_role_without_a_policy" {
  command = plan

  assert {
    condition     = length(aws_iam_role.this) == 0 && length(aws_iam_instance_profile.this) == 0
    error_message = "Instances that need no AWS API access must get no IAM role."
  }
}

run "gets_a_role_scoped_to_the_given_policy" {
  command = plan

  variables {
    iam_policy_json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"ec2:DescribeInstances\",\"Resource\":\"*\"}]}"
  }

  assert {
    condition     = length(aws_iam_role.this) == 1 && aws_iam_role_policy.this[0].policy == var.iam_policy_json
    error_message = "The instance role must carry exactly the policy supplied."
  }
}

run "creates_the_requested_security_group_rules" {
  command = plan

  variables {
    ingress_rules = {
      ssh = { description = "SSH", from_port = 22, to_port = 22, cidr_ipv4 = "203.0.113.10/32" }
    }
    egress_rules = {
      https = { description = "HTTPS", from_port = 443, to_port = 443, cidr_ipv4 = "0.0.0.0/0" }
    }
  }

  assert {
    condition     = keys(aws_vpc_security_group_ingress_rule.this) == ["ssh"] && aws_vpc_security_group_ingress_rule.this["ssh"].cidr_ipv4 == "203.0.113.10/32"
    error_message = "Only the requested ingress rules should be created."
  }

  assert {
    condition     = keys(aws_vpc_security_group_egress_rule.this) == ["https"]
    error_message = "Only the requested egress rules should be created."
  }
}

run "rejects_rules_with_both_cidr_and_security_group" {
  command = plan

  variables {
    ingress_rules = {
      bad = { description = "Ambiguous", from_port = 22, to_port = 22, cidr_ipv4 = "10.0.0.0/8", referenced_security_group_id = "sg-0123456789abcdef0" }
    }
  }

  expect_failures = [var.ingress_rules]
}
