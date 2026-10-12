# IP targets: the controller registers pod IPs directly, so traffic goes from
# the ALB straight to the pod with no NodePort/kube-proxy hop.
resource "aws_lb_target_group" "eks" {
  name        = "${var.name}-eks"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  deregistration_delay = 30

  health_check {
    path                = var.health_check_path
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = { Name = "${var.name}-eks" }

  # Shared-ALB ordering: the listener forwards to this group, so when a
  # platform is switched off the listener must be updated BEFORE the group is
  # deleted. create_before_destroy makes Terraform order it that way; without
  # it the delete runs first and fails with ResourceInUse. (A replacement of
  # this group would need a new name, since names are unique.)
  lifecycle {
    create_before_destroy = true
  }
}

# With the VPC CNI, pods use the node's ENIs and therefore the EKS-managed
# cluster security group.
resource "aws_vpc_security_group_ingress_rule" "pods_from_alb" {
  security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  description       = "HTTP to nginx pods from the load balancer"

  referenced_security_group_id = var.alb_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_to_pods" {
  security_group_id = var.alb_security_group_id
  description       = "HTTP to EKS nginx pods"

  referenced_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}
