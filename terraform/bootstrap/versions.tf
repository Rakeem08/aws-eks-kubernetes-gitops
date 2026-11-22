terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.59"
    }
  }
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      Project     = "aws-eks-kubernetes-gitops"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Component   = "tf-state-bootstrap"
    }
  }
}
