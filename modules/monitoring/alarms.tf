# EC2 basic monitoring publishes every 5 minutes, so two periods means the
# condition held for ~10 minutes - long enough to ignore brief spikes.
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name        = "${var.name}-web-cpu-high"
  alarm_description = "Average CPU across ${var.autoscaling_group_name} is above ${var.cpu_alarm_threshold}%."

  namespace   = "AWS/EC2"
  metric_name = "CPUUtilization"
  dimensions = {
    AutoScalingGroupName = var.autoscaling_group_name
  }

  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.cpu_alarm_threshold
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name        = "${var.name}-web-memory-high"
  alarm_description = "Average memory across ${var.autoscaling_group_name} is above ${var.memory_alarm_threshold}%."

  namespace   = var.metrics_namespace
  metric_name = "mem_used_percent"
  dimensions = {
    AutoScalingGroupName = var.autoscaling_group_name
  }

  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.memory_alarm_threshold
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

# Fires when the load balancer has nothing healthy to send traffic to.
resource "aws_cloudwatch_metric_alarm" "no_healthy_hosts" {
  alarm_name        = "${var.name}-web-no-healthy-hosts"
  alarm_description = "The load balancer has no healthy web servers - the site is down."

  namespace   = "AWS/ApplicationELB"
  metric_name = "HealthyHostCount"
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 3
  comparison_operator = "LessThanThreshold"
  threshold           = 1
  treat_missing_data  = "breaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}
