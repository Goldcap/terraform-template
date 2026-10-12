# A t2.micro NAT instance gives private subnets outbound internet access
# (package installs, CloudWatch, Secrets Manager) within the free tier,
# instead of a NAT Gateway at ~$33/month plus data processing.

data "aws_ssm_parameter" "al2023_ami" {
  count = var.nat_gateway_enabled ? 0 : 1

  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "nat" {
  count = var.nat_gateway_enabled ? 0 : 1

  name        = "${var.name}-nat-instance"
  description = "NAT instance: HTTP/HTTPS from private subnets out to the internet"
  vpc_id      = module.vpc.vpc_id

  tags = { Name = "${var.name}-nat-instance" }
}

resource "aws_vpc_security_group_ingress_rule" "nat_from_private" {
  for_each = var.nat_gateway_enabled ? {} : {
    for pair in setproduct(local.private_subnet_cidrs, [80, 443]) : "${pair[0]}-${pair[1]}" => {
      cidr = pair[0]
      port = pair[1]
    }
  }

  security_group_id = aws_security_group.nat[0].id
  description       = "Port ${each.value.port} from private subnet ${each.value.cidr}"

  cidr_ipv4   = each.value.cidr
  ip_protocol = "tcp"
  from_port   = each.value.port
  to_port     = each.value.port
}

resource "aws_vpc_security_group_egress_rule" "nat_to_internet" {
  for_each = var.nat_gateway_enabled ? toset([]) : toset(["80", "443"])

  security_group_id = aws_security_group.nat[0].id
  description       = "Port ${each.value} to the internet"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = tonumber(each.value)
  to_port     = tonumber(each.value)
}

resource "aws_instance" "nat" {
  count = var.nat_gateway_enabled ? 0 : 1

  ami           = data.aws_ssm_parameter.al2023_ami[0].value
  instance_type = var.nat_instance_type

  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.nat[0].id]
  associate_public_ip_address = true

  # Required for an instance to forward traffic that isn't addressed to it.
  source_dest_check = false

  user_data = templatefile("${path.module}/templates/nat_instance.sh.tftpl", {
    vpc_cidr = var.vpc_cidr
  })
  user_data_replace_on_change = true

  metadata_options {
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  tags = { Name = "${var.name}-nat-instance" }

  lifecycle {
    # Don't replace the NAT every time AWS publishes a new AMI.
    ignore_changes = [ami]
  }
}

resource "aws_route" "private_via_nat_instance" {
  count = var.nat_gateway_enabled ? 0 : length(module.vpc.private_route_table_ids)

  route_table_id         = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat[0].primary_network_interface_id
}
