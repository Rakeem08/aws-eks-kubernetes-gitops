variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "The only AWS account this environment may run in (dev)"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be exactly 12 digits."
  }
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version (N-1 policy)"
  type        = string
}

variable "endpoint_public_access_cidrs" {
  description = "IPs allowed to reach the Kubernetes API (your IP as x.x.x.x/32)"
  type        = list(string)
}

variable "ecr_pull_account_ids" {
  description = "Accounts allowed to pull images from this registry (prod)"
  type        = list(string)
  default     = []
}