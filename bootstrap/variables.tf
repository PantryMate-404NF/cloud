variable "region" {
  description = "AWS region in which the Terraform state bucket is created."
  type        = string
  default     = "ap-northeast-2"
}

variable "terraform_state_bucket_name" {
  description = "Globally unique name for the Terraform remote state S3 bucket."
  type        = string

  validation {
    condition = (
      length(var.terraform_state_bucket_name) >= 3 &&
      length(var.terraform_state_bucket_name) <= 63 &&
      can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.terraform_state_bucket_name)) &&
      !can(regex("\\.\\.", var.terraform_state_bucket_name)) &&
      !can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$", var.terraform_state_bucket_name))
    )
    error_message = "terraform_state_bucket_name must be a valid globally unique S3 bucket name."
  }
}

variable "extra_tags" {
  description = "Additional tags applied to bootstrap resources."
  type        = map(string)
  default     = {}
}
