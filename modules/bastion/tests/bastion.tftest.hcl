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
  vpc_cidr          = "10.0.0.0/16"
  subnet_id         = "subnet-0123456789abcdef0"
  key_name          = "test"
  ssh_allowed_cidrs = ["203.0.113.10/32"]
}

run "ssh_is_only_open_to_the_trusted_ip" {
  command = plan

  assert {
    condition     = keys(aws_vpc_security_group_ingress_rule.ssh) == ["203.0.113.10/32"]
    error_message = "Bastion SSH must only be open to the configured trusted CIDR."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.ssh["203.0.113.10/32"].from_port == 22
    error_message = "The bastion must only accept SSH."
  }
}

run "rejects_ssh_from_anywhere" {
  command = plan

  variables {
    ssh_allowed_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.ssh_allowed_cidrs]
}

run "is_a_hardened_t2_micro_in_the_public_subnet" {
  command = plan

  assert {
    condition     = aws_instance.this.instance_type == "t2.micro" && aws_instance.this.associate_public_ip_address == true
    error_message = "The bastion must be a t2.micro with a public IP."
  }

  assert {
    condition     = aws_instance.this.metadata_options[0].http_tokens == "required"
    error_message = "The bastion must require IMDSv2."
  }

  assert {
    condition     = aws_instance.this.root_block_device[0].encrypted == true
    error_message = "The bastion root volume must be encrypted."
  }
}
