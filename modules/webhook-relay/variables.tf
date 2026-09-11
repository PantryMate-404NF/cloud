variable "name_prefix" {
  description = "Resource name prefix (project-environment)."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the Lambda function will be deployed."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block used for security group egress rules."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the Lambda function (VPC configuration)."
  type        = list(string)
}

variable "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID. An ingress rule will be added to allow Lambda to reach Jenkins."
  type        = string
}

variable "jenkins_internal_url" {
  description = "Jenkins internal NLB URL (http://<nlb-hostname>:8080). Lambda will forward webhook requests here."
  type        = string
}

variable "github_webhook_secret_ssm_name" {
  description = "SSM Parameter Store name containing the GitHub webhook secret."
  type        = string
}

variable "common_tags" {
  description = "Tags applied to all taggable AWS resources."
  type        = map(string)
  default     = {}
}
