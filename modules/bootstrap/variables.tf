variable "project" {
  type    = string
  default = "hello-world"

  description = "Project name, used as a prefix for every resource. Must match the project used by the environments."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,18}$", var.project))
    error_message = "project must be 3-19 lowercase alphanumeric characters or hyphens, starting with a letter."
  }

  # ECS capacity provider names may not start with these.
  validation {
    condition     = !can(regex("^(aws|ecs|fargate)", var.project))
    error_message = "project must not start with \"aws\", \"ecs\" or \"fargate\" (reserved by ECS)."
  }
}

variable "github_repository" {
  type = string

  description = "GitHub repository allowed to assume the CI roles, in 'owner/name' form"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be in 'owner/name' form."
  }
}

variable "github_oidc_subject_prefix" {
  type    = string
  default = null

  description = <<-EOT
    Prefix of the GitHub OIDC "sub" claim. Defaults to "repo:<github_repository>".
    Repositories using GitHub's immutable subject format need the ID-qualified
    prefix instead, e.g. "repo:owner@123/name@456". Look it up with:
      gh api repos/OWNER/REPO/actions/oidc/customization/sub --jq .sub_claim_prefix
  EOT

  validation {
    condition     = var.github_oidc_subject_prefix == null || startswith(coalesce(var.github_oidc_subject_prefix, "x"), "repo:")
    error_message = "github_oidc_subject_prefix must start with \"repo:\"."
  }
}

variable "github_apply_environment" {
  type    = string
  default = "production"

  description = "GitHub Actions environment (with required reviewers) that gates terraform apply"
}

variable "create_github_oidc_provider" {
  type    = bool
  default = true

  description = "Create the GitHub OIDC identity provider. Set false if the account already has one."
}
