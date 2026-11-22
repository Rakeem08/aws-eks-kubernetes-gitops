variable "name" {
  description = "Repository name"
  type        = string
}

variable "image_tag_mutability" {
  description = "IMMUTABLE prevents tags from being overwritten"
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "Must be MUTABLE or IMMUTABLE."
  }
}

variable "force_delete" {
  description = "Allow deleting the repo even if it contains images (true for dev only)"
  type        = bool
  default     = false
}

variable "max_image_count" {
  description = "Number of images to keep"
  type        = number
  default     = 10
}

variable "pull_account_ids" {
  description = "Other AWS account IDs allowed to pull images (e.g. prod)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}