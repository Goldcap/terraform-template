output "state_bucket" {
  value       = module.bootstrap.state_bucket
  description = "S3 bucket for Terraform state. Use as 'bucket' in environments/*/backend.hcl and the TF_STATE_BUCKET GitHub variable."
}

output "github_plan_role_arn" {
  value       = module.bootstrap.github_plan_role_arn
  description = "Set as the AWS_PLAN_ROLE_ARN GitHub variable"
}

output "github_apply_role_arn" {
  value       = module.bootstrap.github_apply_role_arn
  description = "Set as the AWS_APPLY_ROLE_ARN GitHub variable"
}
