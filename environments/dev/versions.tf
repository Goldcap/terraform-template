terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }

  # Partial configuration: bucket and region come from backend.hcl locally
  # (see backend.hcl.example) or from -backend-config flags in CI.
  # use_lockfile enables S3 native state locking - no DynamoDB table needed.
  backend "s3" {
    key          = "dev/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  # Optional: run as a dedicated deployment role (see var.assume_role_arn).
  dynamic "assume_role" {
    for_each = var.assume_role_arn == null ? [] : [var.assume_role_arn]

    content {
      role_arn     = assume_role.value
      session_name = "terraform-${var.project}"
    }
  }

  # Applied to every taggable resource, which makes cost allocation and
  # cleanup straightforward.
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Talks to the EKS cluster when enable_eks = true; unused otherwise. Tokens
# come from the AWS CLI, so it uses whatever AWS credentials Terraform runs
# with (a local profile, or the CI role).
provider "helm" {
  kubernetes = {
    host                   = try(module.web_eks[0].cluster_endpoint, null)
    cluster_ca_certificate = try(base64decode(module.web_eks[0].cluster_certificate_authority), null)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = concat(
        ["eks", "get-token", "--cluster-name", "${local.name}-eks", "--region", var.region, "--output", "json"],
        var.assume_role_arn == null ? [] : ["--role-arn", var.assume_role_arn]
      )
    }
  }
}
