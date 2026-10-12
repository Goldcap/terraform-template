resource "aws_lb_target_group" "web" {
  name        = "${var.name}-web"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  # Drain quickly so scale-in and instance refreshes don't hang around.
  deregistration_delay = 30

  health_check {
    path                = var.health_check_path
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = { Name = "${var.name}-web" }

  # Shared-ALB ordering: the listener forwards to this group, so when a
  # platform is switched off the listener must be updated BEFORE the group is
  # deleted. create_before_destroy makes Terraform order it that way; without
  # it the delete runs first and fails with ResourceInUse. (A replacement of
  # this group would need a new name, since names are unique.)
  lifecycle {
    create_before_destroy = true
  }
}
