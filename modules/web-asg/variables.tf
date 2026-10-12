variable "name" {
  type = string

  description = "Name prefix for web tier resources"
}

variable "vpc_id" {
  type = string

  description = "ID of the VPC"
}

variable "private_subnet_ids" {
  type = list(string)

  description = "Private subnet IDs for the web server Auto Scaling Group"
}

variable "alb_security_group_id" {
  type = string

  description = "Security group of the load balancer (modules/alb) that fronts the web servers"
}

variable "admin_secret_arn" {
  type = string

  description = "ARN of the Secrets Manager secret ({\"username\", \"password\"}) protecting /admin/"
}

variable "bastion_security_group_id" {
  type = string

  description = "Security group of the bastion host, allowed to reach the web servers over SSH and HTTP"
}

variable "key_name" {
  type = string

  description = "EC2 key pair for SSH (via the bastion) to the web servers"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"

  description = "Web server instance type"
}

variable "min_size" {
  type    = number
  default = 1

  description = "Minimum number of web servers"
}

variable "max_size" {
  type    = number
  default = 3

  description = "Maximum number of web servers"

  validation {
    condition     = var.max_size >= 1
    error_message = "max_size must be at least 1."
  }
}

variable "cpu_target_utilization" {
  type    = number
  default = 50

  description = "Average CPU utilization (%) the Auto Scaling Group's target tracking policy aims for"

  validation {
    condition     = var.cpu_target_utilization > 0 && var.cpu_target_utilization < 100
    error_message = "cpu_target_utilization must be between 0 and 100."
  }
}

variable "health_check_path" {
  type    = string
  default = "/health"

  description = "Path the load balancer uses for target health checks"
}

variable "metrics_namespace" {
  type    = string
  default = "CWAgent"

  description = "CloudWatch namespace the CloudWatch agent publishes memory metrics to"
}

variable "permissions_boundary" {
  type    = string
  default = null

  description = "ARN of the IAM permissions boundary to set on every role this module creates (the bootstrap stack's workload_boundary_arn)"
}
