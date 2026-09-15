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