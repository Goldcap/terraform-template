resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  internal           = false

  subnets         = var.public_subnet_ids
  security_groups = [aws_security_group.alb.id]

  drop_invalid_header_fields = true
  enable_deletion_protection = var.alb_deletion_protection

  tags = { Name = "${var.name}-alb" }
}

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
}

# HTTP only: HTTPS needs a domain name for an ACM certificate, which this
# exercise doesn't assume. See README for how to add it.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
