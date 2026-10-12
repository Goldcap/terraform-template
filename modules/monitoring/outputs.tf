output "sns_topic_arn" {
  value       = aws_sns_topic.alerts.arn
  description = "ARN of the SNS topic receiving alarm notifications"
}

output "dashboard_name" {
  value       = aws_cloudwatch_dashboard.this.dashboard_name
  description = "Name of the CloudWatch dashboard"
}

output "cpu_alarm_names" {
  value       = [for alarm in aws_cloudwatch_metric_alarm.cpu_high : alarm.alarm_name]
  description = "Names of the high CPU alarms, one per platform"
}
