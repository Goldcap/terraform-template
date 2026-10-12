# Credentials for the /admin/ area, shared by every web platform.
#
# The password is generated as an ephemeral value and written to Secrets
# Manager through a write-only attribute, so it never appears in Terraform
# state or plan files. EC2 instances fetch it at boot with their instance
# role; ECS injects it into the container from the task definition.
# Increment var.admin_password_version to rotate it.

ephemeral "random_password" "admin" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "admin" {
  name_prefix = "${local.name}-web-admin-"
  description = "Basic auth credentials for the ${local.name} web server /admin/ area"

  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "admin" {
  secret_id = aws_secretsmanager_secret.admin.id

  secret_string_wo = jsonencode({
    username = "admin"
    password = ephemeral.random_password.admin.result
  })
  secret_string_wo_version = var.admin_password_version
}

locals {
  # Taken from the secret *version* so every consumer implicitly waits until
  # the secret has a value before launching anything that reads it.
  admin_secret_arn = aws_secretsmanager_secret_version.admin.secret_id
}
