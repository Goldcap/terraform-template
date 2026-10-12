output "web_url" {
  value       = "http://${module.web.alb_dns_name}"
  description = "URL of the Hello World application (via the load balancer)"
}

output "alb_dns_name" {
  value       = module.web.alb_dns_name
  description = "DNS name of the Application Load Balancer"
}

output "bastion_public_ip" {
  value       = module.bastion.public_ip
  description = "Public IP of the bastion host"
}

output "ssh_bastion_command" {
  value       = "ssh ec2-user@${module.bastion.public_ip}"
  description = "SSH to the bastion host"
}

output "ssh_web_command" {
  value       = "ssh -J ec2-user@${module.bastion.public_ip} ec2-user@<web-server-private-ip>"
  description = "SSH to a web server through the bastion (ProxyJump)"
}

output "autoscaling_group_name" {
  value       = module.web.autoscaling_group_name
  description = "Name of the web server Auto Scaling Group"
}

output "admin_secret_arn" {
  value       = module.web.admin_secret_arn
  description = "Secrets Manager secret with the /admin/ credentials"
}

output "nat_public_ip" {
  value       = module.network.nat_public_ip
  description = "Public IP that outbound traffic from the private subnets uses"
}

output "sns_topic_arn" {
  value       = module.monitoring.sns_topic_arn
  description = "SNS topic for alarm notifications"
}

output "dashboard_url" {
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards/dashboard/${module.monitoring.dashboard_name}"
  description = "CloudWatch dashboard for the web tier"
}
