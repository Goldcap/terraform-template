data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "web" {
  # CloudWatch agent: memory metrics, and only into our namespace.
  statement {
    sid       = "PublishAgentMetrics"
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = [var.metrics_namespace]
    }
  }

  # CloudWatch agent: resolves the instance's AutoScalingGroupName dimension.
  # ec2:DescribeTags does not support resource-level restrictions.
  statement {
    sid       = "ResolveAutoScalingGroupName"
    effect    = "Allow"
    actions   = ["ec2:DescribeTags"]
    resources = ["*"]
  }

  # Read this tier's admin credentials and nothing else.
  statement {
    sid       = "ReadAdminCredentials"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.admin_secret_arn]
  }
}

resource "aws_iam_role" "web" {
  name        = "${var.name}-web"
  description = "Least-privilege role for the ${var.name} web servers."

  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy" "web" {
  name   = "web-server"
  role   = aws_iam_role.web.id
  policy = data.aws_iam_policy_document.web.json
}

resource "aws_iam_instance_profile" "web" {
  name = "${var.name}-web"
  role = aws_iam_role.web.name
}
