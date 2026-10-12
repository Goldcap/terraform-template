data "aws_region" "current" {}

locals {
  region = data.aws_region.current.region

  dimension_list = { for key, source in local.cpu_sources : key => flatten([for name, value in source.dimensions : [name, value]]) }
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
            for key, source in local.cpu_sources :
            concat([source.namespace, "CPUUtilization"], local.dimension_list[key], [{ label = key }])
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
            for key, source in local.memory_sources :
            concat([source.namespace, source.metric_name], flatten([for name, value in source.dimensions : [name, value]]), [{ label = key }])
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
          title  = "Healthy targets per platform"
          region = local.region
          stat   = "Minimum"
          period = 60
          metrics = [
            for key, target_group in var.target_groups :
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", target_group, "LoadBalancer", var.alb_arn_suffix, { label = key }]
          ]
          yAxis = { left = { min = 0 } }
        }
      }
    ]
  })
}
