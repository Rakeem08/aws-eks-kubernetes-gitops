variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "The only AWS account this environment may run in (prod)"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be exactly 12 digits."
  }
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version (same as dev - dev mirrors prod)"
  type        = string
}

variable "endpoint_public_access_cidrs" {
  description = "IPs allowed to reach the Kubernetes API"
  type        = list(string)
}