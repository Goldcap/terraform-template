variable "name" {
  type = string

  description = "Name prefix for the ECS web tier resources"
}

variable "vpc_id" {
  type = string

  description = "ID of the VPC"
}

variable "private_subnet_ids" {
  type = list(string)

  description = "Private subnet IDs for the ECS container instances"
}

variable "alb_security_group_id" {
  type = string

  description = "Security group of the load balancer (modules/alb) that fronts the service"
}

variable "bastion_security_group_id" {
  type = string

  description = "Security group of the bastion host, allowed to SSH to the container instances"
}

variable "key_name" {
  type = string

  description = "EC2 key pair for SSH (via the bastion) to the container instances"
}

variable "admin_secret_arn" {
  type = string

  description = "ARN of the Secrets Manager secret ({\"username\", \"password\"}) protecting /admin/"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"

  description = "Container instance type"
}

variable "min_size" {
  type    = number
  default = 1

  description = "Minimum number of tasks, and of container instances"
}

variable "max_size" {
  type    = number
  default = 3

  description = "Maximum number of tasks, and of container instances"

  validation {
    condition     = var.max_size >= 1
    error_message = "max_size must be at least 1."
  }
}

variable "cpu_target_utilization" {
  type    = number
  default = 50

  description = "Average service CPU utilization (%) the service auto scaling policy aims for"

  validation {
    condition     = var.cpu_target_utilization > 0 && var.cpu_target_utilization < 100
    error_message = "cpu_target_utilization must be between 0 and 100."
  }
}

variable "container_image" {
  type    = string
  default = "public.ecr.aws/nginx/nginx:stable-alpine"

  description = "nginx container image. The default comes from Amazon ECR Public, which avoids Docker Hub rate limits."
}

variable "task_cpu" {
  type    = number
  default = 128

  description = "CPU units reserved per task (1024 = 1 vCPU)"
}

variable "task_memory" {
  type    = number
  default = 128

  description = "Hard memory limit per task, in MiB"
}

variable "health_check_path" {
  type    = string
  default = "/health"

  description = "Path the load balancer and the container health check use"
}

variable "log_retention_days" {
  type    = number
  default = 7

  description = "How long to keep container logs in CloudWatch Logs"
}

variable "egress_dependency" {
  type    = string
  default = null

  description = "Pass the network module's egress_id. Ties this platform's teardown to the NAT path so it outlives the workloads that need it to drain."
}

variable "permissions_boundary" {
  type    = string
  default = null

  description = "ARN of the IAM permissions boundary to set on every role this module creates (the bootstrap stack's workload_boundary_arn)"
}
