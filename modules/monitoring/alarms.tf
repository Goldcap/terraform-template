locals {
  # Every CPU source behind the load balancer, keyed by platform name.
  cpu_sources = merge(
    {
      for key, asg in var.autoscaling_groups : key => {
        namespace   = "AWS/EC2"
        description = "Auto Scaling Group ${asg.name}"
        dimensions  = { AutoScalingGroupName = asg.name }
      }
    },
    {
      for key, svc in var.ecs_services : key => {
        namespace   = "AWS/ECS"
        description = "ECS service ${svc.service_name}"
        dimensions  = { ClusterName = svc.cluster_name, ServiceName = svc.service_name }
      }
    }
  )

  memory_sources = merge(
    {
      for key, asg in var.autoscaling_groups : key => {
        namespace   = var.metrics_namespace
        metric_name = "mem_used_percent"
        description = "Auto Scaling Group ${asg.name}"
        dimensions  = { AutoScalingGroupName = asg.name }
      } if asg.has_memory_metrics
    },
    {
      for key, svc in var.ecs_services : key => {
        namespace   = "AWS/ECS"
        metric_name = "MemoryUtilization"
        description = "ECS service ${svc.service_name}"
        dimensions  = { ClusterName = svc.cluster_name, ServiceName = svc.service_name }
      }
    }
  )
}

# The basic metrics publish every 5 minutes (EC2) or every minute (ECS); two
# 5-minute periods means the condition held for ~10 minutes, long enough to
# ignore brief spikes.
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  for_each = local.cpu_sources

  alarm_name        = "${var.name}-${each.key}-cpu-high"
  alarm_description = "Average CPU of ${each.value.description} is above ${var.cpu_alarm_threshold}%."

  namespace   = each.value.namespace
  metric_name = "CPUUtilization"
  dimensions  = each.value.dimensions

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
  for_each = local.memory_sources

  alarm_name        = "${var.name}-${each.key}-memory-high"
  alarm_description = "Average memory of ${each.value.description} is above ${var.memory_alarm_threshold}%."

  namespace   = each.value.namespace
  metric_name = each.value.metric_name
  dimensions  = each.value.dimensions

  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.memory_alarm_threshold
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

# Fires when a platform has nothing healthy behind the load balancer.
resource "aws_cloudwatch_metric_alarm" "no_healthy_hosts" {
  for_each = var.target_groups

  alarm_name        = "${var.name}-${each.key}-no-healthy-hosts"
  alarm_description = "The load balancer has no healthy ${each.key} targets."

  namespace   = "AWS/ApplicationELB"
  metric_name = "HealthyHostCount"
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = each.value
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
