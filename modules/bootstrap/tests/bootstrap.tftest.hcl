# Plan-time unit tests. The AWS provider is mocked, so these run in CI on
# every pull request without credentials and without creating anything:
#   terraform init -backend=false && terraform test

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
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
  github_repository = "example-org/example-repo"
}

run "state_bucket_is_private_versioned_and_encrypted" {
  command = plan

  assert {
    condition     = aws_s3_bucket.state.bucket == "hello-world-tfstate-123456789012-us-east-1"
    error_message = "The state bucket name should include the account ID and region to be globally unique."
  }

  assert {
    condition     = aws_s3_bucket_versioning.state.versioning_configuration[0].status == "Enabled"
    error_message = "State bucket versioning must be enabled so state can be recovered."
  }

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.state.block_public_acls,
      aws_s3_bucket_public_access_block.state.block_public_policy,
      aws_s3_bucket_public_access_block.state.ignore_public_acls,
      aws_s3_bucket_public_access_block.state.restrict_public_buckets,
    ])
    error_message = "All public access to the state bucket must be blocked."
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.state.rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
    error_message = "The state bucket must be encrypted at rest."
  }
}

run "apply_role_is_only_assumable_from_the_approval_environment" {
  command = plan

  # The trust policies reference the OIDC provider ARN, which is normally only
  # known after apply. Supplying it at plan time lets the policies resolve.
  override_resource {
    target          = aws_iam_openid_connect_provider.github[0]
    override_during = plan
    values = {
      arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    }
  }

  assert {
    condition = anytrue([
      for c in one(data.aws_iam_policy_document.github_trust_apply.statement).condition :
      c.variable == "token.actions.githubusercontent.com:sub" && c.test == "StringEquals" &&
      toset(c.values) == toset(["repo:example-org/example-repo:environment:production"])
    ])
    error_message = "The apply role must only trust the repository's production environment."
  }

  assert {
    condition = anytrue([
      for c in one(data.aws_iam_policy_document.github_trust_plan.statement).condition :
      c.variable == "token.actions.githubusercontent.com:sub" &&
      toset(c.values) == toset(["repo:example-org/example-repo:*"])
    ])
    error_message = "The plan role must only trust this repository."
  }
}

run "can_reuse_an_existing_oidc_provider" {
  command = plan

  variables {
    create_github_oidc_provider = false
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.github) == 0
    error_message = "create_github_oidc_provider = false should not create a second OIDC provider."
  }
}

run "rejects_malformed_repository" {
  command = plan

  variables {
    github_repository = "not-a-repo"
  }

  expect_failures = [var.github_repository]
}
