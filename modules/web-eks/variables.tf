variable "name" {
  type = string

  description = "Name prefix for the EKS web tier resources"
}

variable "vpc_id" {
  type = string

  description = "ID of the VPC"
}

variable "private_subnet_ids" {
  type = list(string)

  description = "Private subnet IDs for the cluster and its nodes"
}

variable "alb_security_group_id" {
  type = string

  description = "Security group of the load balancer (modules/alb) that fronts the pods"
}

variable "admin_secret_arn" {
  type = string

  description = "ARN of the Secrets Manager secret ({\"username\", \"password\"}) protecting /admin/"
}

variable "kubernetes_version" {
  type    = string
  default = "1.36"

  description = "EKS Kubernetes version"
}

variable "node_instance_type" {
  type    = string
  default = "t3.small"

  description = "Worker node instance type. t3.small (2 GiB, 11 pods) is the smallest that comfortably fits the system pods plus nginx."
}

variable "node_min_size" {
  type    = number
  default = 1

  description = "Minimum number of worker nodes"
}

variable "node_max_size" {
  type    = number
  default = 3

  description = "Maximum number of worker nodes"
}

variable "app_values" {
  type    = list(string)
  default = []

  description = <<-EOT
    Environment-specific Helm values (YAML documents) for the hello-world chart,
    layered over the chart's own values.yaml - typically
    file("helm/hello-world.yaml") from the environment. Use them for app tuning
    (replicas, autoscaling, resources, image). Infrastructure wiring (target
    group, secret, service account) is set by this module and always wins.
  EOT
}

variable "health_check_path" {
  type    = string
  default = "/health"

  description = "Path the load balancer and the pod probes use"
}

variable "endpoint_public_access_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]

  description = "CIDRs allowed to reach the public Kubernetes API endpoint (authentication is still required). GitHub-hosted runners have no fixed IPs."
}

variable "cluster_admin_principal_arns" {
  type    = list(string)
  default = []

  description = "IAM principals granted cluster admin through EKS access entries (e.g. the CI apply role)"
}

variable "cluster_viewer_principal_arns" {
  type    = list(string)
  default = []

  description = "IAM principals granted read-only cluster access, including Secrets (needed to read Helm release state during plan)"
}

variable "bootstrap_cluster_creator_admin" {
  type    = bool
  default = true

  description = "Give whoever creates the cluster admin access. Set false when the creator is already in cluster_admin_principal_arns."
}

variable "load_balancer_controller_chart_version" {
  type    = string
  default = "3.6.0"

  description = "Version of the aws-load-balancer-controller Helm chart. Keep policies/aws_load_balancer_controller.json in step with it."
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
