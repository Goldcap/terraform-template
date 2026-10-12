# Load balancer: HTTP in from the allowed CIDRs. Each web platform module adds
# its own egress rule on this security group to reach its targets, so the
# load balancer can only talk to what is actually behind it.
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "Application Load Balancer: HTTP from clients, HTTP to web servers"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-alb" }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  for_each = toset(var.ingress_cidrs)

  security_group_id = aws_security_group.alb.id
  description       = "HTTP from clients"

  cidr_ipv4   = each.value
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
}

resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  internal           = false

  subnets         = var.public_subnet_ids
  security_groups = [aws_security_group.alb.id]

  drop_invalid_header_fields = true
  enable_deletion_protection = var.deletion_protection

  tags = { Name = "${var.name}-alb" }
}

# HTTP only: HTTPS needs a domain name for an ACM certificate, which this
# exercise doesn't assume. See README for how to add it.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"

    forward {
      dynamic "target_group" {
        for_each = var.targets

        content {
          arn    = target_group.value.target_group_arn
          weight = target_group.value.weight
        }
      }
    }
  }
}
