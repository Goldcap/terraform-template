variable "name" {
  type = string

  description = "Name of the instance. Also used for its security group and (if any) IAM role."
}

variable "description" {
  type = string

  description = "What the instance is for. Used as the security group description."
}

variable "vpc_id" {
  type = string

  description = "ID of the VPC the instance is deployed into"
}

variable "subnet_id" {
  type = string

  description = "ID of the subnet to launch the instance in"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"

  description = "EC2 instance type"
}

variable "ami_id" {
  type    = string
  default = null

  description = "AMI to launch. Defaults to the latest Amazon Linux 2023 (x86_64) from AWS's public SSM parameter."
}

variable "associate_public_ip_address" {
  type    = bool
  default = false

  description = "Give the instance a public IP. Only for instances in public subnets that must be reachable from (or reach) the internet directly."
}

variable "source_dest_check" {
  type    = bool
  default = true

  description = "Set false for instances that route traffic not addressed to them (e.g. NAT instances)"
}

variable "key_name" {
  type    = string
  default = null

  description = "EC2 key pair for SSH. Leave null for instances nobody should log in to."
}

variable "user_data" {
  type    = string
  default = null

  description = "cloud-init user data (plain text)"
}

variable "user_data_replace_on_change" {
  type    = bool
  default = false

  description = "Replace the instance when user_data changes, instead of updating it in place (which needs a stop/start)"
}

variable "root_volume_size" {
  type    = number
  default = 8

  description = "Root volume size in GiB (gp3, encrypted)"
}

variable "ingress_rules" {
  type = map(object({
    description                  = string
    from_port                    = number
    to_port                      = number
    ip_protocol                  = optional(string, "tcp")
    cidr_ipv4                    = optional(string)
    referenced_security_group_id = optional(string)
  }))
  default = {}

  description = "Security group ingress rules, keyed by a stable name. Each rule needs exactly one of cidr_ipv4 or referenced_security_group_id."

  validation {
    condition     = alltrue([for rule in values(var.ingress_rules) : (rule.cidr_ipv4 == null) != (rule.referenced_security_group_id == null)])
    error_message = "Each ingress rule needs exactly one of cidr_ipv4 or referenced_security_group_id."
  }
}

variable "egress_rules" {
  type = map(object({
    description                  = string
    from_port                    = number
    to_port                      = number
    ip_protocol                  = optional(string, "tcp")
    cidr_ipv4                    = optional(string)
    referenced_security_group_id = optional(string)
  }))
  default = {}

  description = "Security group egress rules, keyed by a stable name. Each rule needs exactly one of cidr_ipv4 or referenced_security_group_id."

  validation {
    condition     = alltrue([for rule in values(var.egress_rules) : (rule.cidr_ipv4 == null) != (rule.referenced_security_group_id == null)])
    error_message = "Each egress rule needs exactly one of cidr_ipv4 or referenced_security_group_id."
  }
}

variable "iam_policy_json" {
  type    = string
  default = null

  description = "IAM policy (JSON) granting the instance only what it needs. Leave null for an instance with no IAM role at all."
}
