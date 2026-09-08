variable "bucket_name" {
  description = "Globally unique S3 bucket name."
  type        = string
}

variable "versioning_enabled" {
  description = "Enable S3 object versioning."
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Allow Terraform to delete a non-empty bucket. Keep false for safety."
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Tags applied to the S3 bucket."
  type        = map(string)
  default     = {}
}

