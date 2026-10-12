variable "project" {
  type    = string
  default = "hello-world"

  description = "Project name, used as a prefix for every resource. Must match the project used by the environments."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,18}$", var.project))
    error_message = "project must be 3-19 lowercase alphanumeric characters or hyphens, starting with a letter."
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
