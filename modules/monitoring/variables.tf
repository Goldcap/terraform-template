variable "name" {
  type = string

  description = "Name prefix for monitoring resources"
}

variable "autoscaling_group_name" {
  type = string

  description = "Name of the web server Auto Scaling Group to monitor"
}

variable "alb_arn_suffix" {
  type = string

  description = "ARN suffix of the Application Load Balancer"
}

variable "target_group_arn_suffix" {
  type = string

  description = "ARN suffix of the web server target group"
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
