variable "name" {
  description = "Name prefix for resources (e.g. rakeem-dev)"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name, used for subnet discovery tags"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block, e.g. 10.20.0.0/16."
  }
}

variable "az_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2
    error_message = "Use at least 2 AZs for high availability."
  }
}

variable "private_subnets" {
  description = "CIDRs for private subnets (one per AZ) - EKS nodes and pods live here"
  type        = list(string)
}

variable "public_subnets" {
  description = "CIDRs for public subnets (one per AZ) - load balancers and NAT live here"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "true = one NAT (cheaper, dev). false = one NAT per AZ (resilient, prod)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Extra tags to apply to all network resources"
  type        = map(string)
  default     = {}
}