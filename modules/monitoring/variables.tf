variable "name" {
  type = string

  description = "Name prefix for monitoring resources"
}

variable "alb_arn_suffix" {
  type = string

  description = "ARN suffix of the Application Load Balancer"
}

variable "autoscaling_groups" {
  type = map(object({
    name               = string
    has_memory_metrics = optional(bool, false)
  }))
  default = {}

  description = <<-EOT
    EC2-based web tiers to monitor, keyed by platform name. CPU comes from the
    AWS/EC2 metrics of the group; memory from the CloudWatch agent when
    has_memory_metrics is true.
  EOT
}

variable "ecs_services" {
  type = map(object({
    cluster_name = string
    service_name = string
  }))
  default = {}

  description = "ECS services to monitor, keyed by platform name. CPU and memory come from the free AWS/ECS service metrics."
}

variable "target_groups" {
  type    = map(string)
  default = {}

  description = "Load balancer target group ARN suffixes, keyed by platform name. Each gets a \"no healthy hosts\" alarm."
}

variable "alarm_email" {
  type = string

  description = "Email address subscribed to alarm notifications. AWS sends a confirmation email that must be accepted."

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alarm_email))
    error_message = "alarm_email must be a valid email address."
  }
}

variable "cpu_alarm_threshold" {
  type    = number
  default = 70

  description = "Average CPU utilization (%) across the Auto Scaling Group that triggers an alarm"
}

variable "memory_alarm_threshold" {
  type    = number
  default = 80

  description = "Average memory utilization (%) across the Auto Scaling Group that triggers an alarm"
}

variable "metrics_namespace" {
  type    = string
  default = "CWAgent"

  description = "CloudWatch namespace the CloudWatch agent publishes memory metrics to"
}

variable "monthly_budget_usd" {
  type    = number
  default = 10

  description = "Monthly cost budget in USD. Alerts at 80% actual and 100% forecasted spend. Set to null to disable."
}
