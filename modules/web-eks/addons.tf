# Managed add-ons, at the newest version EKS offers for the cluster version.

locals {
  # Needed before nodes can become Ready (networking, pod credentials).
  addons_before_nodes = ["vpc-cni", "kube-proxy", "eks-pod-identity-agent"]

  # Need somewhere to schedule their pods.
  addons_after_nodes = ["coredns", "metrics-server", "aws-secrets-store-csi-driver-provider"]
}

data "aws_eks_addon_version" "this" {
  for_each = toset(concat(local.addons_before_nodes, local.addons_after_nodes))

  addon_name         = each.value
  kubernetes_version = aws_eks_cluster.this.version
  most_recent        = true
}

resource "aws_eks_addon" "before_nodes" {
  for_each = toset(local.addons_before_nodes)

  cluster_name  = aws_eks_cluster.this.name
  addon_name    = each.value
  addon_version = data.aws_eks_addon_version.this[each.value].version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "after_nodes" {
  for_each = toset(local.addons_after_nodes)

  cluster_name  = aws_eks_cluster.this.name
  addon_name    = each.value
  addon_version = data.aws_eks_addon_version.this[each.value].version

  # One CoreDNS replica is plenty for a single-service demo and leaves room on
  # small nodes; the Secrets Store CSI driver ships with the AWS provider.
  configuration_values = each.value == "coredns" ? jsonencode({ replicaCount = 1 }) : null

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.this]
}
