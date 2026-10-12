output "instance_id" {
  value       = aws_instance.this.id
  description = "ID of the instance"
}

output "public_ip" {
  value       = aws_instance.this.public_ip
  description = "Public IP of the instance (null without associate_public_ip_address)"
}

output "private_ip" {
  value       = aws_instance.this.private_ip
  description = "Private IP of the instance"
}

output "primary_network_interface_id" {
  value       = aws_instance.this.primary_network_interface_id
  description = "ID of the instance's primary network interface (e.g. a route target for NAT instances)"
}

output "security_group_id" {
  value       = aws_security_group.this.id
  description = "ID of the instance's security group"
}

output "ingress_rules" {
  value       = var.ingress_rules
  description = "The ingress rules applied to the instance's security group"
}

output "iam_role_name" {
  value       = try(aws_iam_role.this[0].name, null)
  description = "Name of the instance's IAM role (null when it has none)"
}
