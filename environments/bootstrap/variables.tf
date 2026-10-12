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

variable "assume_role_arn" {
  type    = string
  default = null

  description = <<-EOT
    IAM role Terraform assumes for every AWS call (and, for EKS, for cluster
    tokens). Lets any automation - GitHub Actions, Jenkins, Atlantis, a
    laptop - run as a dedicated deployment role instead of whatever
    credentials it starts with. Never run Terraform as the root user.
  EOT

  validation {
    condition     = var.assume_role_arn == null || can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:role/", var.assume_role_arn))
    error_message = "assume_role_arn must be an IAM role ARN."
  }
}
