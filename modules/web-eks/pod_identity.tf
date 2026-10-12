# EKS Pod Identity: each workload's service account gets its own IAM role.

data "aws_iam_policy_document" "pod_identity_assume_role" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

# --- AWS Load Balancer Controller ------------------------------------------------
# The upstream policy for the controller version in use (vendored from
# kubernetes-sigs/aws-load-balancer-controller docs/install/iam_policy.json).

resource "aws_iam_role" "load_balancer_controller" {
  name        = "${var.name}-eks-lb-controller"
  description = "AWS Load Balancer Controller in the ${var.name} EKS cluster."

  assume_role_policy   = data.aws_iam_policy_document.pod_identity_assume_role.json
  permissions_boundary = var.permissions_boundary
}

resource "aws_iam_role_policy" "load_balancer_controller" {
  name   = "aws-load-balancer-controller"
  role   = aws_iam_role.load_balancer_controller.id
  policy = file("${path.module}/policies/aws_load_balancer_controller.json")
}

resource "aws_eks_pod_identity_association" "load_balancer_controller" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.load_balancer_controller.arn
}

# --- nginx ----------------------------------------------------------------------
# Used only by the Secrets Store CSI driver to mount the admin secret.

data "aws_iam_policy_document" "nginx" {
  statement {
    sid    = "ReadAdminCredentials"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [var.admin_secret_arn]
  }
}

resource "aws_iam_role" "nginx" {
  name        = "${var.name}-eks-nginx"
  description = "nginx pods in the ${var.name} EKS cluster: read the admin secret only."

  assume_role_policy   = data.aws_iam_policy_document.pod_identity_assume_role.json
  permissions_boundary = var.permissions_boundary
}

resource "aws_iam_role_policy" "nginx" {
  name   = "read-admin-secret"
  role   = aws_iam_role.nginx.id
  policy = data.aws_iam_policy_document.nginx.json
}

resource "aws_eks_pod_identity_association" "nginx" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = local.app_namespace
  service_account = local.app_service_account
  role_arn        = aws_iam_role.nginx.arn
}
