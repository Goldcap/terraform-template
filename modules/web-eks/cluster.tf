data "aws_region" "current" {}

data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name        = "${var.name}-eks-cluster"
  description = "EKS control plane role for ${var.name}."

  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Kubernetes Secrets are envelope-encrypted by EKS by default (AWS owned key);
# a customer managed KMS key would add $1/month. Control plane logs are off to
# avoid CloudWatch Logs ingestion charges.
resource "aws_eks_cluster" "this" {
  name     = "${var.name}-eks"
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.endpoint_public_access_cidrs
  }

  # IAM access entries only (no aws-auth ConfigMap).
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = var.bootstrap_cluster_creator_admin
  }

  # Self-managed vpc-cni, kube-proxy and CoreDNS are replaced by the managed
  # add-ons in addons.tf.
  bootstrap_self_managed_addons = false

  depends_on = [aws_iam_role_policy_attachment.cluster]

  lifecycle {
    # Only meaningful at creation; changing it later would replace the cluster.
    ignore_changes = [access_config[0].bootstrap_cluster_creator_admin_permissions]
  }
}

# --- Cluster access (EKS access entries) ----------------------------------------

resource "aws_eks_access_entry" "admins" {
  for_each = toset(var.cluster_admin_principal_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
}

resource "aws_eks_access_policy_association" "admins" {
  for_each = toset(var.cluster_admin_principal_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.admins[each.value].principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_access_entry" "viewers" {
  for_each = toset(var.cluster_viewer_principal_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
}

resource "aws_eks_access_policy_association" "viewers" {
  for_each = toset(var.cluster_viewer_principal_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.viewers[each.value].principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminViewPolicy"

  access_scope {
    type = "cluster"
  }
}
