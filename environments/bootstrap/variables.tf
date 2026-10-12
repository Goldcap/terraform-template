variable "project" {
  type    = string
  default = "hello-world"

  description = "Project name, used as a prefix for every resource. Must match the project used by the environments."
}

variable "region" {
  type    = string
  default = "us-east-1"

  description = "AWS region for the state bucket and the infrastructure CI deploys"
}

variable "github_repository" {
  type = string

  description = "GitHub repository allowed to assume the CI roles, in 'owner/name' form"
}

variable "github_oidc_subject_prefix" {
  type    = string
  default = null

  description = "GitHub OIDC sub claim prefix, for repositories using immutable subjects (see modules/bootstrap)"
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
