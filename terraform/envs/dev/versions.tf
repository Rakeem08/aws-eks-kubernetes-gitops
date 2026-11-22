terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.59"
    }
  }

  # Remote state in S3 with native locking.
  # Bucket name is supplied at init time from dev.s3.tfbackend (git-ignored).
  backend "s3" {
    key          = "envs/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      Project     = "aws-eks-kubernetes-gitops"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}