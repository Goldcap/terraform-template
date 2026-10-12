# Tasks use bridge networking with dynamic host ports (ECS assigns one from the
# ephemeral range for each task), so the load balancer must reach that range.
locals {
  ephemeral_ports = { from = 32768, to = 65535 }
}

resource "aws_security_group" "instances" {
  name        = "${var.name}-ecs"
  description = "ECS container instances: task ports from ALB, SSH from bastion"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-ecs" }
}

resource "aws_vpc_security_group_ingress_rule" "tasks_from_alb" {
  security_group_id = aws_security_group.instances.id
  description       = "Dynamic task ports from the load balancer"

  referenced_security_group_id = var.alb_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = local.ephemeral_ports.from
  to_port                      = local.ephemeral_ports.to
}

resource "aws_vpc_security_group_ingress_rule" "ssh_from_bastion" {
  security_group_id = aws_security_group.instances.id
  description       = "SSH from the bastion host"

  referenced_security_group_id = var.bastion_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.instances.id
  description       = "HTTPS via NAT for the ECS agent, image pulls, logs and Secrets Manager"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}

# The load balancer reaches the tasks through this rule on its security group.
resource "aws_vpc_security_group_egress_rule" "alb_to_tasks" {
  security_group_id = var.alb_security_group_id
  description       = "Dynamic task ports to ECS container instances"

  referenced_security_group_id = aws_security_group.instances.id
  ip_protocol                  = "tcp"
  from_port                    = local.ephemeral_ports.from
  to_port                      = local.ephemeral_ports.to
}
