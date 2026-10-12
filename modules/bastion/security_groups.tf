resource "aws_security_group" "this" {
  name        = "${var.name}-bastion"
  description = "Bastion host: SSH in from trusted IPs, SSH/HTTP out to the VPC"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-bastion" }
}

# Keyed by position rather than by CIDR so the trusted IP doesn't appear in
# resource addresses (and therefore in public CI logs).
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = { for index, cidr in var.ssh_allowed_cidrs : tostring(index) => cidr }

  security_group_id = aws_security_group.this.id
  description       = "SSH from trusted IP"

  cidr_ipv4   = each.value
  ip_protocol = "tcp"
  from_port   = 22
  to_port     = 22
}

# Egress is scoped to the VPC rather than to the web server security group to
# avoid a dependency cycle between the two modules. The web server security
# group still only admits traffic from this group, so the effective path is
# the same.
resource "aws_vpc_security_group_egress_rule" "to_vpc" {
  for_each = toset(["22", "80"])

  security_group_id = aws_security_group.this.id
  description       = "Port ${each.value} to instances in the VPC"

  cidr_ipv4   = var.vpc_cidr
  ip_protocol = "tcp"
  from_port   = tonumber(each.value)
  to_port     = tonumber(each.value)
}

resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.this.id
  description       = "HTTPS for OS updates and the AWS CLI"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}
