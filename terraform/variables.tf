variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name used to identify project resources"
  type        = string
  default     = "tech-challenge-2"
}

variable "cluster_name" {
  description = "Name of the Amazon EKS cluster"
  type        = string
  default     = "tech-challenge-2-eks"
}

variable "kubernetes_version" {
  description = "Kubernetes version used by Amazon EKS"
  type        = string
  default     = "1.35"
}

variable "node_instance_types" {
  description = "EC2 instance types used by the Kubernetes worker nodes"
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_desired_size" {
  description = "Number of worker nodes created initially"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

variable "jenkins_key_name" {
  description = "AWS EC2 key pair used to access the Jenkins server"
  type        = string
}

variable "jenkins_allowed_cidr" {
  description = "Public IP address allowed to access Jenkins and SSH"
  type        = string

  validation {
    condition     = can(cidrhost(var.jenkins_allowed_cidr, 0))
    error_message = "jenkins_allowed_cidr must be a valid CIDR such as 203.0.113.10/32."
  }
}

variable "jenkins_instance_type" {
  description = "EC2 instance type used by Jenkins"
  type        = string
  default     = "t3.medium"
}