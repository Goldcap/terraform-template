# An IAM role is only created when the caller supplies a policy. Instances
# that need no AWS API access get no role at all.

data "aws_iam_policy_document" "assume_role" {
  count = var.iam_policy_json == null ? 0 : 1

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  count = var.iam_policy_json == null ? 0 : 1

  name        = var.name
  description = "Least-privilege role for the ${var.name} instance."

  assume_role_policy   = data.aws_iam_policy_document.assume_role[0].json
  permissions_boundary = var.permissions_boundary
}

resource "aws_iam_role_policy" "this" {
  count = var.iam_policy_json == null ? 0 : 1

  name   = var.name
  role   = aws_iam_role.this[0].id
  policy = var.iam_policy_json
}

resource "aws_iam_instance_profile" "this" {
  count = var.iam_policy_json == null ? 0 : 1

  name = var.name
  role = aws_iam_role.this[0].name
}
