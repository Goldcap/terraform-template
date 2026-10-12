terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # The bootstrap stack creates the remote state bucket, so it necessarily
  # starts with local state. Once applied, its state can optionally be
  # migrated into the bucket it created (see README).
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

  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      Stack     = "bootstrap"
    }
  }
}
