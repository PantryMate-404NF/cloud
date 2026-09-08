variable "name_prefix" {
  description = "Prefix used for CloudWatch resource names."
  type        = string
}

variable "log_retention_days" {
  description = "Retention period for the shared application log group."
  type        = number
  default     = 14
}

variable "common_tags" {
  description = "Tags applied to CloudWatch resources."
  type        = map(string)
  default     = {}
}

