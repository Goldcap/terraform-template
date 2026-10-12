output "state_bucket" {
  value       = aws_s3_bucket.state.id
  description = "S3 bucket for Terraform state. Use as 'bucket' in environments/*/backend.hcl and the TF_STATE_BUCKET GitHub variable."
}

output "github_plan_role_arn" {
  value       = aws_iam_role.github_plan.arn
  description = "Set as the AWS_PLAN_ROLE_ARN GitHub variable"
}

output "github_apply_role_arn" {
  value       = aws_iam_role.github_apply.arn
  description = "Set as the AWS_APPLY_ROLE_ARN GitHub variable"
}
