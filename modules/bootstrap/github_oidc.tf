# GitHub Actions authenticates to AWS with short-lived OIDC credentials, so no
# long-lived access keys are stored in GitHub.
#
# Two roles keep plan and apply separate:
#   * plan  - read-only, assumable from any branch or pull request in the repo.
#   * apply - can change infrastructure, assumable ONLY from the GitHub
#             environment that requires a manual approval.

locals {
  github_subject_prefix = coalesce(var.github_oidc_subject_prefix, "repo:${var.github_repository}")

  github_oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : "arn:aws:iam::${local.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "github_trust_plan" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${local.github_subject_prefix}:*"]
    }
  }
}

data "aws_iam_policy_document" "github_trust_apply" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${local.github_subject_prefix}:environment:${var.github_apply_environment}"]
    }
  }
}

# Both roles read and write state (S3 native locking writes a .tflock object)
# and read the web server secret, because refreshing
# aws_secretsmanager_secret_version calls GetSecretValue.
data "aws_iam_policy_document" "terraform_state" {
  statement {
    sid       = "StateBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }

  statement {
    sid    = "StateObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = ["${aws_s3_bucket.state.arn}/*"]
  }

  statement {
    sid       = "ReadProjectSecrets"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${var.project}-*"]
  }
}

data "aws_iam_policy_document" "terraform_apply" {
  statement {
    sid    = "ManageInfrastructureInRegion"
    effect = "Allow"
    actions = [
      "ec2:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
      "cloudwatch:*",
      "ecs:*",
      "application-autoscaling:*",
      "eks:*"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [local.region]
    }
  }

  statement {
    sid       = "ManageProjectTopics"
    effect    = "Allow"
    actions   = ["sns:*"]
    resources = ["arn:aws:sns:${local.region}:${local.account_id}:${var.project}-*"]
  }

  statement {
    sid       = "ManageProjectSecrets"
    effect    = "Allow"
    actions   = ["secretsmanager:*"]
    resources = ["arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${var.project}-*"]
  }

  statement {
    sid     = "ManageProjectLogGroups"
    effect  = "Allow"
    actions = ["logs:*"]
    resources = [
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/ecs/${var.project}-*",
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/ecs/${var.project}-*:*"
    ]
  }

  statement {
    sid       = "ManageProjectBudgets"
    effect    = "Allow"
    actions   = ["budgets:*"]
    resources = ["arn:aws:budgets::${local.account_id}:budget/${var.project}-*"]
  }

  statement {
    sid    = "ManageProjectInstanceRoles"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:UntagInstanceProfile"
    ]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${var.project}-*",
      "arn:aws:iam::${local.account_id}:instance-profile/${var.project}-*"
    ]
  }

  # Only the AWS managed policies the project actually attaches.
  statement {
    sid    = "AttachApprovedManagedPolicies"
    effect = "Allow"
    actions = [
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy"
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/${var.project}-*"]

    condition {
      test     = "ArnEquals"
      variable = "iam:PolicyARN"
      values = [
        "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
        "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
        "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
        "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
        "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      ]
    }
  }

  statement {
    sid       = "PassProjectRolesToServices"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/${var.project}-*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values = [
        "ec2.amazonaws.com",
        "ecs-tasks.amazonaws.com",
        "eks.amazonaws.com",
        "pods.eks.amazonaws.com"
      ]
    }
  }

  statement {
    sid       = "CreateServiceLinkedRoles"
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values = [
        "autoscaling.amazonaws.com",
        "elasticloadbalancing.amazonaws.com",
        "ecs.amazonaws.com",
        "ecs.application-autoscaling.amazonaws.com",
        "eks.amazonaws.com",
        "eks-nodegroup.amazonaws.com"
      ]
    }
  }
}

# Plan role
resource "aws_iam_role" "github_plan" {
  name        = "${var.project}-github-plan"
  description = "Read-only role GitHub Actions uses to run terraform plan."

  assume_role_policy   = data.aws_iam_policy_document.github_trust_plan.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "github_plan_read_only" {
  role       = aws_iam_role.github_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "github_plan_state" {
  name   = "terraform-state"
  role   = aws_iam_role.github_plan.id
  policy = data.aws_iam_policy_document.terraform_state.json
}

# Apply role
resource "aws_iam_role" "github_apply" {
  name        = "${var.project}-github-apply"
  description = "Role GitHub Actions uses to run terraform apply after manual approval."

  assume_role_policy   = data.aws_iam_policy_document.github_trust_apply.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "github_apply_read_only" {
  role       = aws_iam_role.github_apply.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "github_apply_state" {
  name   = "terraform-state"
  role   = aws_iam_role.github_apply.id
  policy = data.aws_iam_policy_document.terraform_state.json
}

resource "aws_iam_role_policy" "github_apply_infrastructure" {
  name   = "terraform-apply"
  role   = aws_iam_role.github_apply.id
  policy = data.aws_iam_policy_document.terraform_apply.json
}
