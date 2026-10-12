output "cluster_name" {
  value       = aws_ecs_cluster.this.name
  description = "Name of the ECS cluster"
}

output "service_name" {
  value       = aws_ecs_service.nginx.name
  description = "Name of the nginx ECS service"
}

output "target_group_arn" {
  value       = aws_lb_target_group.ecs.arn
  description = "ARN of the service's load balancer target group"
}

output "target_group_arn_suffix" {
  value       = aws_lb_target_group.ecs.arn_suffix
  description = "ARN suffix of the target group, used as a CloudWatch dimension"
}

output "autoscaling_group_name" {
  value       = aws_autoscaling_group.ecs.name
  description = "Name of the Auto Scaling Group backing the capacity provider"
}

output "security_group_id" {
  value       = aws_security_group.instances.id
  description = "Security group ID of the container instances"
}
