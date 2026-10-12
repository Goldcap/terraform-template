data "aws_region" "current" {}

locals {
  region = data.aws_region.current.region
}

# Up to 3 dashboards are free.
resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = var.name

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Web CPU utilization (%)"
          region = local.region
          stat   = "Average"
          period = 300
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.autoscaling_group_name]
          ]
          annotations = {
            horizontal = [{ label = "Alarm", value = var.cpu_alarm_threshold }]
          }
          yAxis = { left = { min = 0, max = 100 } }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Web memory utilization (%)"
          region = local.region
          stat   = "Average"
          period = 300
          metrics = [
            [var.metrics_namespace, "mem_used_percent", "AutoScalingGroupName", var.autoscaling_group_name]
          ]
          annotations = {
            horizontal = [{ label = "Alarm", value = var.memory_alarm_threshold }]
          }
          yAxis = { left = { min = 0, max = 100 } }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ALB requests and 5XX errors"
          region = local.region
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Instances"
          region = local.region
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", var.target_group_arn_suffix, "LoadBalancer", var.alb_arn_suffix, { stat = "Minimum", label = "Healthy targets" }],
            ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", var.autoscaling_group_name, { stat = "Average", label = "In service" }],
            ["AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", var.autoscaling_group_name, { stat = "Average", label = "Desired" }]
          ]
          yAxis = { left = { min = 0 } }
        }
      }
    ]
  })
}
