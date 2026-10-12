output "sns_topic_arn" {
  value       = aws_sns_topic.alerts.arn
  description = "ARN of the SNS topic receiving alarm notifications"
}

output "dashboard_name" {
  value       = aws_cloudwatch_dashboard.this.dashboard_name
  description = "Name of the CloudWatch dashboard"
}

output "cpu_alarm_name" {
  value       = aws_cloudwatch_metric_alarm.cpu_high.alarm_name
  description = "Name of the high CPU alarm"
}
