variable "name" {
  type = string

  description = "Name prefix for the load balancer resources"
}

variable "vpc_id" {
  type = string

  description = "ID of the VPC"
}

variable "public_subnet_ids" {
  type = list(string)

  description = "Public subnet IDs for the load balancer (at least 2 AZs)"

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "An Application Load Balancer needs subnets in at least two availability zones."
  }
}

variable "ingress_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]

  description = "CIDR blocks allowed to reach the load balancer on port 80"
}

variable "targets" {
  type = map(object({
    target_group_arn = string
    weight           = optional(number, 1)
  }))

  description = <<-EOT
    Target groups the HTTP listener forwards to, keyed by platform name (e.g.
    "ec2", "ecs", "eks"). Traffic is split between them by weight, so several
    platforms can serve side by side - useful for comparing them or migrating
    between them.
  EOT

  validation {
    condition     = length(var.targets) >= 1 && length(var.targets) <= 5
    error_message = "Enable between 1 and 5 targets (an ALB forward action supports up to 5 weighted target groups)."
  }

  validation {
    condition     = alltrue([for target in values(var.targets) : target.weight >= 0 && target.weight <= 999])
    error_message = "Target weights must be between 0 and 999."
  }
}

variable "deletion_protection" {
  type    = bool
  default = false

  description = "Protect the load balancer from deletion. Leave false for easy teardown of this demo."
}
