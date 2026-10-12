# Plan-time unit tests. The AWS and Helm providers are mocked, so these run in
# CI on every pull request without credentials, a cluster, or anything created:
#   terraform init -backend=false && terraform test

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }

  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "ami-0123456789abcdef0"
    }
  }

  # IAM policy documents must be valid JSON for the resources that use them.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_data "aws_eks_addon_version" {
    defaults = {
      version = "v1.0.0-eksbuild.1"
    }
  }

  mock_resource "aws_eks_cluster" {
    defaults = {
      vpc_config = [{ cluster_security_group_id = "sg-0eeeeeeeeeeeeeeee" }]
    }
  }
}

mock_provider "helm" {}

variables {
  name                          = "test"
  vpc_id                        = "vpc-0123456789abcdef0"
  private_subnet_ids            = ["subnet-0000000000000000c", "subnet-0000000000000000d"]
  alb_security_group_id         = "sg-0aaaaaaaaaaaaaaaa"
  admin_secret_arn              = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test-admin-AbCdEf"
  cluster_admin_principal_arns  = ["arn:aws:iam::123456789012:role/test-github-apply"]
  cluster_viewer_principal_arns = ["arn:aws:iam::123456789012:role/test-github-plan"]
  app_values                    = ["autoscaling:\n  maxReplicas: 3\n"]
}

run "cluster_uses_access_entries_in_private_subnets" {
  command = plan

  assert {
    condition     = aws_eks_cluster.this.access_config[0].authentication_mode == "API"
    error_message = "Cluster access must be managed with IAM access entries only."
  }

  assert {
    condition     = toset(aws_eks_cluster.this.vpc_config[0].subnet_ids) == toset(var.private_subnet_ids)
    error_message = "The cluster must use the private subnets."
  }

  assert {
    condition     = toset(keys(aws_eks_access_policy_association.admins)) == toset(var.cluster_admin_principal_arns) && toset(keys(aws_eks_access_policy_association.viewers)) == toset(var.cluster_viewer_principal_arns)
    error_message = "Admins and viewers must get access entries."
  }

  assert {
    condition     = one(values(aws_eks_access_policy_association.viewers)).policy_arn == "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminViewPolicy"
    error_message = "Viewers (the CI plan role) must get read-only access."
  }
}

run "nodes_are_hardened_t3_small_in_private_subnets" {
  command = plan

  assert {
    condition     = toset(aws_eks_node_group.this.instance_types) == toset(["t3.small"]) && toset(aws_eks_node_group.this.subnet_ids) == toset(var.private_subnet_ids)
    error_message = "Nodes must be t3.small in the private subnets."
  }

  assert {
    condition     = aws_launch_template.nodes.metadata_options[0].http_tokens == "required" && aws_launch_template.nodes.metadata_options[0].http_put_response_hop_limit == 1
    error_message = "Nodes must require IMDSv2 with a hop limit that keeps pods away from node credentials."
  }

  assert {
    condition     = aws_launch_template.nodes.block_device_mappings[0].ebs[0].encrypted == "true"
    error_message = "Node volumes must be encrypted."
  }

  assert {
    condition     = aws_eks_node_group.this.scaling_config[0].min_size == 1 && aws_eks_node_group.this.scaling_config[0].max_size == 3
    error_message = "The node group must hold 1 to 3 nodes."
  }
}

run "pods_are_ip_targets_reachable_only_from_the_alb" {
  command = plan

  assert {
    condition     = aws_lb_target_group.eks.target_type == "ip"
    error_message = "Pods must be registered as IP targets."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.pods_from_alb.referenced_security_group_id == var.alb_security_group_id && aws_vpc_security_group_ingress_rule.pods_from_alb.cidr_ipv4 == null
    error_message = "Pods must only accept HTTP from the load balancer's security group."
  }
}

run "nginx_can_only_read_the_admin_secret" {
  command = plan

  assert {
    condition     = aws_eks_pod_identity_association.nginx.namespace == "hello-world" && aws_eks_pod_identity_association.nginx.service_account == "nginx"
    error_message = "The nginx service account must get its role through EKS Pod Identity."
  }

  assert {
    condition     = toset(one(data.aws_iam_policy_document.nginx.statement).resources) == toset([var.admin_secret_arn])
    error_message = "nginx's role must only be able to read the admin secret."
  }
}

run "environment_values_are_layered_under_terraform_wiring" {
  command = plan

  # The wiring layer includes the target group ARN, normally only known after
  # apply. Supplying it at plan time lets the values be inspected.
  override_resource {
    target          = aws_lb_target_group.eks
    override_during = plan
    values = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test-eks/0123456789abcdef"
    }
  }

  assert {
    condition     = helm_release.app.values[0] == var.app_values[0]
    error_message = "Environment overrides must be applied over the chart defaults."
  }

  assert {
    condition     = yamldecode(helm_release.app.values[length(helm_release.app.values) - 1]).adminSecretArn == var.admin_secret_arn
    error_message = "Terraform's infrastructure wiring must be the last (winning) values layer."
  }
}
