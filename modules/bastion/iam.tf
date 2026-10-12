data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# The bastion only needs to look up the private IPs of the web servers.
# ec2:DescribeInstances does not support resource-level restrictions.
data "aws_iam_policy_document" "this" {
  statement {
    sid       = "DiscoverInstances"
    effect    = "Allow"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "this" {
  name        = "${var.name}-bastion"
  description = "Least-privilege role for the ${var.name} bastion host."

  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy" "this" {
  name   = "describe-instances"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.this.json
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-bastion"
  role = aws_iam_role.this.name
}
