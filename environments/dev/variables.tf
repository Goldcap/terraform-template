variable "project" {
  type    = string
  default = "hello-world"

  description = "Project name, used as a prefix for every resource. Must match the bootstrap stack."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,18}$", var.project))
    error_message = "project must be 3-19 lowercase alphanumeric characters or hyphens, starting with a letter."
  }
}

variable "environment" {
  type    = string
  default = "dev"

  description = "Environment name"

  validation {
    condition     = can(regex("^[a-z0-9]{1,8}$", var.environment))
    error_message = "environment must be 1-8 lowercase alphanumeric characters."
  }
}

variable "region" {
  type    = string
  default = "us-east-1"

  description = "AWS region to deploy into"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"

  description = "CIDR block for the VPC"
}

variable "nat_gateway_enabled" {
  type    = bool
  default = false

  description = "Use a managed NAT Gateway (~$33/month) instead of the free-tier eligible NAT instance"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"

  description = "Instance type for the bastion, NAT instance and web servers"
}

variable "ssh_allowed_cidrs" {
  type = list(string)

  description = "Specific IPs allowed to SSH to the bastion, each as a single-host /32 - e.g. your public IP (curl -s https://checkip.amazonaws.com)"

  validation {
    condition     = length(var.ssh_allowed_cidrs) > 0 && alltrue([for cidr in var.ssh_allowed_cidrs : can(cidrhost(cidr, 0)) && endswith(cidr, "/32")])
    error_message = "ssh_allowed_cidrs must be pinned to specific IPs: single-host /32 CIDRs only (no ranges, no 0.0.0.0/0)."
  }
}

variable "ssh_public_key" {
  type = string

  description = "SSH public key (OpenSSH format) for the bastion and web servers"

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)) ", var.ssh_public_key))
    error_message = "ssh_public_key must be an OpenSSH public key (ssh-ed25519, ssh-rsa or ecdsa)."
  }
}

variable "alarm_email" {
  type      = string
  sensitive = true

  description = "Email address for CloudWatch alarm and budget notifications"
}

variable "enable_ec2" {
  type    = bool
  default = true

  description = "Serve the site from nginx on an EC2 Auto Scaling Group (modules/web-asg)"
}

variable "enable_ecs" {
  type    = bool
  default = true

  description = "Serve the site from an nginx service on ECS with an EC2 capacity provider (modules/web-ecs)"

  validation {
    condition     = var.enable_ec2 || var.enable_ecs
    error_message = "Enable at least one web platform (enable_ec2 or enable_ecs)."
  }
}

variable "platform_weights" {
  type    = map(number)
  default = {}

  description = "Load balancer weight per enabled platform, e.g. { ec2 = 1, ecs = 3 }. Platforms not listed get weight 1."

  validation {
    condition     = alltrue([for platform in keys(var.platform_weights) : contains(["ec2", "ecs"], platform)])
    error_message = "platform_weights keys must be platform names: ec2 or ecs."
  }
}

variable "admin_password_version" {
  type    = number
  default = 1

  description = "Increment to generate and store a new /admin/ password in Secrets Manager"
}

variable "web_min_size" {
  type    = number
  default = 1

  description = "Minimum number of web servers (EC2) or tasks and container instances (ECS)"
}

variable "web_max_size" {
  type    = number
  default = 3

  description = "Maximum number of web servers (EC2) or tasks and container instances (ECS)"
}

variable "cpu_alarm_threshold" {
  type    = number
  default = 70

  description = "Average CPU (%) across the web servers that triggers an alarm notification"
}

variable "cpu_target_utilization" {
  type    = number
  default = 50

  description = "Average CPU (%) the Auto Scaling Group scales to maintain. Keep below cpu_alarm_threshold so scaling reacts before the alarm fires."
}

variable "monthly_budget_usd" {
  type    = number
  default = 10

  description = "Monthly AWS Budget in USD (null disables the budget)"
}
