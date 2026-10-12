output "instance_id" {
  value       = aws_instance.this.id
  description = "ID of the bastion instance"
}

output "public_ip" {
  value       = aws_instance.this.public_ip
  description = "Public IP of the bastion host"
}

output "security_group_id" {
  value       = aws_security_group.this.id
  description = "Security group ID of the bastion host"
}
