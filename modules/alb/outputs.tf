output "dns_name" {
  value       = aws_lb.this.dns_name
  description = "Public DNS name of the load balancer"
}

output "arn_suffix" {
  value       = aws_lb.this.arn_suffix
  description = "ARN suffix of the load balancer, used as a CloudWatch dimension"
}

output "security_group_id" {
  value       = aws_security_group.alb.id
  description = "Security group ID of the load balancer"
}

output "listener_arn" {
  value       = aws_lb_listener.http.arn
  description = "ARN of the HTTP listener"
}
