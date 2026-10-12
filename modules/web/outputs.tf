output "alb_dns_name" {
  value       = aws_lb.this.dns_name
  description = "Public DNS name of the Application Load Balancer"
}

output "alb_arn_suffix" {
  value       = aws_lb.this.arn_suffix
  description = "ARN suffix of the load balancer, used as a CloudWatch dimension"
}

output "target_group_arn" {
  value       = aws_lb_target_group.web.arn
  description = "ARN of the web server target group"
}

output "target_group_arn_suffix" {
  value       = aws_lb_target_group.web.arn_suffix
  description = "ARN suffix of the target group, used as a CloudWatch dimension"
}

output "autoscaling_group_name" {
  value       = aws_autoscaling_group.web.name
  description = "Name of the web server Auto Scaling Group"
}

output "web_security_group_id" {
  value       = aws_security_group.web.id
  description = "Security group ID of the web servers"
}

output "alb_security_group_id" {
  value       = aws_security_group.alb.id
  description = "Security group ID of the load balancer"
}

output "admin_secret_arn" {
  value       = aws_secretsmanager_secret.admin.arn
  description = "ARN of the Secrets Manager secret holding the /admin/ credentials"
}
