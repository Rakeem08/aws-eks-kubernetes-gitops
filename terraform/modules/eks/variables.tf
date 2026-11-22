# --- Cluster ---
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version (must be in standard support)"
  type        = string
}

variable "log_retention_days" {
  description = "Days to keep control plane logs in CloudWatch"
  type        = number
  default     = 7
}

# --- Network (from the network module) ---
variable "vpc_id" {
  description = "VPC ID for the cluster"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the cluster and nodes"
  type        = list(string)
}

variable "endpoint_public_access_cidrs" {
  description = "IPs allowed to reach the Kubernetes API from the internet"
  type        = list(string)

  validation {
    condition     = !contains(var.endpoint_public_access_cidrs, "0.0.0.0/0")
    error_message = "Do not open the Kubernetes API to the whole internet (0.0.0.0/0)."
  }
}

# --- Access ---
variable "cluster_admin_principal_arns" {
  description = "IAM role ARNs that get cluster-admin inside Kubernetes"
  type        = list(string)
  default     = []
}

variable "cluster_view_principal_arns" {
  description = "IAM role ARNs that get read-only access inside Kubernetes"
  type        = list(string)
  default     = []
}

# --- Nodes ---
variable "node_instance_types" {
  description = "Instance types for worker nodes (several types improve Spot availability)"
  type        = list(string)
  default     = ["t3.medium", "t3a.medium"]
}

variable "node_capacity_type" {
  description = "SPOT (cheaper, can be interrupted) or ON_DEMAND (stable)"
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["SPOT", "ON_DEMAND"], var.node_capacity_type)
    error_message = "Must be SPOT or ON_DEMAND."
  }
}

variable "node_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 2
}

variable "node_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 4

  validation {
    condition     = var.node_max_size >= var.node_desired_size && var.node_desired_size >= var.node_min_size
    error_message = "Node sizes must satisfy: min <= desired <= max."
  }
}

# --- Tags ---
variable "tags" {
  description = "Tags to apply to all EKS resources"
  type        = map(string)
  default     = {}
}