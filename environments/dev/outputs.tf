output "web_url" {
  value       = "http://${module.alb.dns_name}"
  description = "URL of the Hello World application (via the load balancer)"
}

output "alb_dns_name" {
  value       = module.alb.dns_name
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

output "enabled_platforms" {
  value       = keys(local.platforms)
  description = "Web platforms currently serving behind the load balancer"
}

output "platform_weights" {
  value       = { for platform in keys(local.platforms) : platform => lookup(var.platform_weights, platform, 1) }
  description = "Share of load balancer traffic each enabled platform receives"
}

output "target_group_arns" {
  value       = { for platform, config in local.platforms : platform => config.target_group_arn }
  description = "Load balancer target group per enabled platform"
}

output "autoscaling_group_name" {
  value       = var.enable_ec2 ? module.web_asg[0].autoscaling_group_name : null
  description = "Name of the EC2 web server Auto Scaling Group (null when enable_ec2 = false)"
}

output "ecs_cluster_name" {
  value       = var.enable_ecs ? module.web_ecs[0].cluster_name : null
  description = "Name of the ECS cluster (null when enable_ecs = false)"
}

output "ecs_service_name" {
  value       = var.enable_ecs ? module.web_ecs[0].service_name : null
  description = "Name of the nginx ECS service (null when enable_ecs = false)"
}

output "admin_secret_arn" {
  value       = aws_secretsmanager_secret.admin.arn
  description = "Secrets Manager secret with the /admin/ credentials"
}

output "cpu_alarm_names" {
  value       = module.monitoring.cpu_alarm_names
  description = "High CPU CloudWatch alarms, one per enabled platform"
}

output "eks_cluster_name" {
  value       = var.enable_eks ? module.web_eks[0].cluster_name : null
  description = "Name of the EKS cluster (null when enable_eks = false). Use: aws eks update-kubeconfig --name <this>"
}

output "eks_node_group_name" {
  value       = var.enable_eks ? module.web_eks[0].node_group_name : null
  description = "Name of the EKS managed node group (null when enable_eks = false)"
}
