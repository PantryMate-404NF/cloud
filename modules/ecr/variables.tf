variable "repository_names" {
  description = "Names of ECR repositories to create."
  type        = set(string)
}

variable "image_tag_mutability" {
  description = "Whether image tags can be overwritten."
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Enable basic vulnerability scanning when an image is pushed."
  type        = bool
  default     = true
}

variable "untagged_image_expiration_days" {
  description = "Days to retain untagged images before lifecycle expiration."
  type        = number
  default     = 14
}

variable "max_image_count" {
  description = "Maximum number of images retained per repository."
  type        = number
  default     = 30
}

variable "common_tags" {
  description = "Tags applied to ECR repositories."
  type        = map(string)
  default     = {}
}

