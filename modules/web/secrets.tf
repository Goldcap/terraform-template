# Credentials for the web server's /admin/ area.
#
# The password is generated as an ephemeral value and written to Secrets
# Manager through a write-only attribute, so it never appears in Terraform
# state or plan files. Instances fetch it at boot with their IAM role.
# Increment var.admin_password_version to rotate it.

ephemeral "random_password" "admin" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "admin" {
  name_prefix = "${var.name}-web-admin-"
  description = "Basic auth credentials for the ${var.name} web server /admin/ area"

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
