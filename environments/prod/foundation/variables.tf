variable "region" {
  description = "AWS region in which PROD Foundation resources will be managed."
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

variable "extra_tags" {
  description = "Additional common tags for future PROD Foundation resources."
  type        = map(string)
  default     = {}
}
