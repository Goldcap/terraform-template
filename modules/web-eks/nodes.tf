data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "nodes" {
  name        = "${var.name}-eks-node"
  description = "EKS worker node role for ${var.name}."

  assume_role_policy   = data.aws_iam_policy_document.ec2_assume_role.json
  permissions_boundary = var.permissions_boundary
}

resource "aws_iam_role_policy_attachment" "nodes" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ])

  role       = aws_iam_role.nodes.name
  policy_arn = each.value
}

resource "aws_launch_template" "nodes" {
  name_prefix = "${var.name}-eks-node-"
  description = "Launch template for the ${var.name} EKS worker nodes."

  # IMDSv2 only, with a hop limit of 1 so pods can't reach the node role's
  # credentials. Pods that need AWS access get their own role via Pod Identity.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_type           = "gp3"
      volume_size           = 20
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.name}-eks-node" }
  }

  tag_specifications {
    resource_type = "volume"
    tags          = { Name = "${var.name}-eks-node" }
  }
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-eks"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids

  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = [var.node_instance_type]
  capacity_type  = "ON_DEMAND"

  launch_template {
    id      = aws_launch_template.nodes.id
    version = aws_launch_template.nodes.latest_version
  }

  scaling_config {
    min_size     = var.node_min_size
    max_size     = var.node_max_size
    desired_size = var.node_min_size
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes,
    aws_eks_addon.before_nodes,
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}
