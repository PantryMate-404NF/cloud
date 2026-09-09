variable "region" {
  description = "AWS region in which PROD Runtime resources will be managed."
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Project identifier used in future PROD resource names and tags."
  type        = string
  default     = "pantry-mate"
}

variable "environment" {
  description = "Deployment environment identifier."
  type        = string
  default     = "prod"

  validation {
    condition     = var.environment == "prod"
    error_message = "This root module manages only the prod environment."
  }
}

variable "terraform_state_bucket_name" {
  description = "Bootstrap S3 bucket that will contain the PROD Foundation State."
  type        = string
  default     = null
  nullable    = true
}

variable "foundation_state_key" {
  description = "S3 object key reserved for the PROD Foundation State."
  type        = string
  default     = "prod/foundation/terraform.tfstate"
}

variable "extra_tags" {
  description = "Additional common tags for future PROD Runtime resources."
  type        = map(string)
  default     = {}
}
