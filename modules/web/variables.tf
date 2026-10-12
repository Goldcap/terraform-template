variable "name" {
  type = string

  description = "Name prefix for web tier resources"
}

variable "vpc_id" {
  type = string

  description = "ID of the VPC"
}

variable "public_subnet_ids" {
  type = list(string)

  description = "Public subnet IDs for the Application Load Balancer (at least 2 AZs)"

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "An Application Load Balancer needs subnets in at least two availability zones."
  }
}

variable "private_subnet_ids" {
  type = list(string)

  description = "Private subnet IDs for the web server Auto Scaling Group"
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

variable "alb_ingress_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]

  description = "CIDR blocks allowed to reach the load balancer on port 80"
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

variable "admin_password_version" {
  type    = number
  default = 1

  description = "Increment to generate and store a new /admin password in Secrets Manager"
}

variable "alb_deletion_protection" {
  type    = bool
  default = false

  description = "Protect the load balancer from deletion. Leave false for easy teardown of this demo."
}
