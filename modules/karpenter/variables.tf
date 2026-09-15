variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "namespace" {
  type        = string
  description = "Karpenter namespace"
  default     = "karpenter"
}

variable "karpenter_version" {
  type        = string
  description = "Karpenter Helm chart version"
  default     = "1.12.1"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Subnets used by Karpenter nodes"
}

variable "cluster_security_group_id" {
  type        = string
  description = "Security group used by Karpenter nodes"
}

variable "instance_types" {
  type        = list(string)
  description = "Allowed instance types"

  default = [
    "t3.medium",
    "t3.large",
    "m5.large",
    "m6i.large"
  ]
}

variable "capacity_types" {
  type        = list(string)
  description = "Allowed Karpenter capacity types"

  default = [
    "spot"
  ]
}

variable "cpu_limit" {
  type        = string
  description = "Maximum total CPU managed by this NodePool"
  default     = "16"
}

variable "tags" {
  type    = map(string)
  default = {}
}