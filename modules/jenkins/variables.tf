variable "name_prefix" {
  description = "Resource name prefix (project-environment)."
  type        = string
}

variable "eks_cluster_name" {
  description = "EKS cluster name where Jenkins will be deployed."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider for IRSA."
  type        = string
}

variable "oidc_provider_url" {
  description = "EKS OIDC provider URL without https:// prefix."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for Jenkins."
  type        = string
  default     = "jenkins"
}

variable "jenkins_admin_password" {
  description = "Jenkins admin user password."
  type        = string
  sensitive   = true
}

variable "github_webhook_secret" {
  description = "Shared secret for validating GitHub webhook payloads (HMAC-SHA256)."
  type        = string
  sensitive   = true
}

variable "github_api_token" {
  description = "GitHub Personal Access Token for Jenkins to clone repos and call the GitHub API."
  type        = string
  sensitive   = true
}

variable "github_org" {
  description = "GitHub organisation or user that owns the source repositories."
  type        = string
}

variable "frontend_repo_name" {
  description = "GitHub repository name for the frontend service."
  type        = string
}

variable "backend_repo_name" {
  description = "GitHub repository name for the backend service."
  type        = string
}

variable "manage_node_label" {
  description = "Value of the 'role' node label used to schedule the Jenkins controller."
  type        = string
  default     = "manage"
}

variable "worker_node_label" {
  description = "Value of the 'role' node label used to schedule Jenkins build agents."
  type        = string
  default     = "worker"
}

variable "artifact_bucket_name" {
  description = "S3 bucket name used for build artifacts."
  type        = string
}

variable "common_tags" {
  description = "Tags applied to all taggable AWS resources."
  type        = map(string)
  default     = {}
}
