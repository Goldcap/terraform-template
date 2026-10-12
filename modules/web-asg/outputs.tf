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
