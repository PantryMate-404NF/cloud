variable "region" {
  type        = string
  description = "AWS region"
  default     = "ap-northeast-2"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "manage_pod_identity_agent" {
  type        = bool
  description = "Whether Terraform should install the EKS Pod Identity Agent"
  default     = true
}

variable "common_tags" {
  type = map(string)

  default = {
    Project     = "pantry-mate"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
variable "app_namespace" {
  type        = string
  description = "Namespace where the application workloads run"
  default     = "app"
}

variable "items_bucket_name" {
  type        = string
  description = "S3 bucket for app item images (created manually)"
  default     = "pantry-mate-items-542119828072"
}

variable "items_s3_service_accounts" {
  type        = list(string)
  description = "ServiceAccounts in app_namespace allowed to read/write the items bucket"
  default = [
    "pantry-mate-product",
    "pantry-mate-pantry-recipe",
    "pantry-mate-user",
    "pantry-mate-ai"
  ]
}
