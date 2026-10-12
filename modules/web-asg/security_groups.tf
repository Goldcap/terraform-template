# The load balancer (modules/alb) reaches the web servers through this rule,
# which lives here so the load balancer can only reach targets that exist.
resource "aws_vpc_security_group_egress_rule" "alb_to_web" {
  security_group_id = var.alb_security_group_id
  description       = "HTTP to web servers"

  referenced_security_group_id = aws_security_group.web.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

# Web servers: no CIDR-based ingress at all. HTTP is accepted only from the
# load balancer and the bastion, and SSH only from the bastion.
resource "aws_security_group" "web" {
  name        = "${var.name}-web"
  description = "Web servers: HTTP from ALB and bastion, SSH from bastion"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-web" }
}

resource "aws_vpc_security_group_ingress_rule" "web_http_from_alb" {
  security_group_id = aws_security_group.web.id
  description       = "HTTP from the load balancer"

  referenced_security_group_id = var.alb_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

resource "aws_vpc_security_group_ingress_rule" "web_http_from_bastion" {
  security_group_id = aws_security_group.web.id
  description       = "HTTP from the bastion host"

  referenced_security_group_id = var.bastion_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

resource "aws_vpc_security_group_ingress_rule" "web_ssh_from_bastion" {
  security_group_id = aws_security_group.web.id
  description       = "SSH from the bastion host"

  referenced_security_group_id = var.bastion_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

resource "aws_vpc_security_group_egress_rule" "web_https" {
  security_group_id = aws_security_group.web.id
  description       = "HTTPS via NAT for packages, CloudWatch and Secrets Manager"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}
