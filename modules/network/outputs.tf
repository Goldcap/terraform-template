output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "ID of the VPC"
}

output "vpc_cidr" {
  value       = module.vpc.vpc_cidr_block
  description = "CIDR block of the VPC"
}

output "public_subnet_ids" {
  value       = module.vpc.public_subnets
  description = "IDs of the public subnets (ALB, bastion, NAT)"
}

output "private_subnet_ids" {
  value       = module.vpc.private_subnets
  description = "IDs of the private subnets (web servers)"
}

output "nat_public_ip" {
  value       = var.nat_gateway_enabled ? module.vpc.nat_public_ips[0] : module.nat_instance[0].public_ip
  description = "Public IP that private-subnet traffic egresses from"
}

output "egress_id" {
  value = var.nat_gateway_enabled ? module.vpc.natgw_ids[0] : aws_route.private_via_nat_instance[0].id

  description = <<-EOT
    Identifies the private subnets' outbound path (the NAT instance route or
    the NAT Gateway). Workloads that need egress to shut down cleanly (e.g. an
    ECS agent draining a service) take it as a dependency so Terraform keeps
    the path until they are gone.
  EOT
}
