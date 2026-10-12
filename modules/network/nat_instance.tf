# A t2.micro NAT instance gives private subnets outbound internet access
# (package installs, CloudWatch, Secrets Manager) within the free tier,
# instead of a NAT Gateway at ~$33/month plus data processing.

module "nat_instance" {
  source = "../ec2"
  count  = var.nat_gateway_enabled ? 0 : 1

  name          = "${var.name}-nat-instance"
  description   = "NAT instance: HTTP/HTTPS from private subnets out to the internet"
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.public_subnets[0]
  instance_type = var.nat_instance_type

  associate_public_ip_address = true

  # Required for an instance to forward traffic that isn't addressed to it.
  source_dest_check = false

  user_data = templatefile("${path.module}/templates/nat_instance.sh.tftpl", {
    vpc_cidr = var.vpc_cidr
  })
  user_data_replace_on_change = true

  ingress_rules = {
    for pair in setproduct(local.private_subnet_cidrs, [80, 443]) : "${pair[0]}-${pair[1]}" => {
      description = "Port ${pair[1]} from private subnet ${pair[0]}"
      from_port   = pair[1]
      to_port     = pair[1]
      cidr_ipv4   = pair[0]
    }
  }

  egress_rules = {
    for port in [80, 443] : tostring(port) => {
      description = "Port ${port} to the internet"
      from_port   = port
      to_port     = port
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
}

resource "aws_route" "private_via_nat_instance" {
  count = var.nat_gateway_enabled ? 0 : length(module.vpc.private_route_table_ids)

  route_table_id         = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = module.nat_instance[0].primary_network_interface_id
}
