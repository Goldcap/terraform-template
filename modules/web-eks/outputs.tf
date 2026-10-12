output "cluster_name" {
  value       = aws_eks_cluster.this.name
  description = "Name of the EKS cluster"
}

output "cluster_endpoint" {
  value       = aws_eks_cluster.this.endpoint
  description = "Kubernetes API endpoint"
}

output "cluster_certificate_authority" {
  value       = aws_eks_cluster.this.certificate_authority[0].data
  description = "Base64-encoded cluster CA certificate"
}

output "target_group_arn" {
  value       = aws_lb_target_group.eks.arn
  description = "ARN of the target group the pods are registered in"
}

output "target_group_arn_suffix" {
  value       = aws_lb_target_group.eks.arn_suffix
  description = "ARN suffix of the target group, used as a CloudWatch dimension"
}

output "node_autoscaling_group_name" {
  value       = aws_eks_node_group.this.resources[0].autoscaling_groups[0].name
  description = "Auto Scaling Group behind the managed node group"
}

output "node_group_name" {
  value       = aws_eks_node_group.this.node_group_name
  description = "Name of the managed node group"
}
