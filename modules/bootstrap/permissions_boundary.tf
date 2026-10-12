# Permissions boundary for every role the environments create.
#
# The apply role can create and edit project roles, so without a boundary an
# approved change could create a role with an admin inline policy and pass it
# to an instance. The apply role may only create or edit roles that carry this
# boundary, which caps them at the services the workloads actually use (the
# web servers, ECS agent, EKS control plane, nodes and the load balancer
# controller). Each role's own policy still grants far less than this.

data "aws_iam_policy_document" "workload_boundary" {
  statement {
    sid    = "WorkloadServices"
    effect = "Allow"
    actions = [
      "ec2:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
      "cloudwatch:*",
      "logs:*",
      "ecs:*",
      "ecr:*",
      "eks:*",
      "eks-auth:*",
      "acm:Describe*",
      "acm:List*",
      "cognito-idp:DescribeUserPoolClient",
      "waf-regional:*",
      "wafv2:*",
      "shield:*",
      "tag:GetResources",
      "kms:CreateGrant",
      "kms:DescribeKey",
      "iam:CreateServiceLinkedRole",
      "iam:ListServerCertificates",
      "iam:GetServerCertificate"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ProjectSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = ["arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${var.project}-*"]
  }
}

resource "aws_iam_policy" "workload_boundary" {
  name        = "${var.project}-workload-boundary"
  description = "Permissions boundary for roles created by the ${var.project} environments."
  policy      = data.aws_iam_policy_document.workload_boundary.json
}
