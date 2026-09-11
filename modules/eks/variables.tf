variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version."
  type        = string
}

variable "cluster_role_arn" {
  description = "IAM role ARN used by the EKS control plane."
  type        = string
}

variable "node_role_arn" {
  description = "IAM role ARN shared by the managed node groups."
  type        = string
}

variable "ssh_key_name" {
  description = "Name of the existing EC2 Key Pair used for managed node SSH access."
  type        = string
}

variable "ssh_source_security_group_ids" {
  description = "Bastion security group IDs allowed to SSH to the managed nodes."
  type        = list(string)
}

variable "node_ami_id" {
  description = "Canonical Ubuntu EKS AMI ID used by all managed node groups."
  type        = string

  validation {
    condition     = can(regex("^ami-[0-9a-f]+$", var.node_ami_id))
    error_message = "node_ami_id must be a valid AMI ID."
  }
}

variable "node_ami_root_device_name" {
  description = "Root device name reported by the selected Ubuntu EKS AMI."
  type        = string
  default     = "/dev/sda1"
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used by the control plane and node groups."
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Whether the Kubernetes API has a public endpoint."
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public Kubernetes API endpoint. Restrict before apply."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "authentication_mode" {
  description = "EKS access-entry authentication mode."
  type        = string
  default     = "API_AND_CONFIG_MAP"

  validation {
    condition     = contains(["API", "API_AND_CONFIG_MAP", "CONFIG_MAP"], var.authentication_mode)
    error_message = "authentication_mode must be API, API_AND_CONFIG_MAP, or CONFIG_MAP."
  }
}

variable "cluster_log_types" {
  description = "EKS control-plane log types sent to CloudWatch Logs."
  type        = set(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cluster_log_retention_days" {
  description = "Retention period for EKS control-plane logs."
  type        = number
  default     = 14
}

variable "node_groups" {
  description = "Managed node group definitions keyed by logical role."
  type = map(object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    capacity_type  = optional(string, "ON_DEMAND")
    disk_size      = optional(number, 30)
    enable_nvidia  = optional(bool, false)
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = optional(string)
      effect = string
    })), [])
  }))

  validation {
    condition = alltrue([
      for group in values(var.node_groups) :
      group.min_size >= 0 &&
      group.desired_size >= group.min_size &&
      group.desired_size <= group.max_size &&
      group.max_size >= 1
    ])
    error_message = "Each node group's size settings must satisfy 0 <= min <= desired <= max and max >= 1."
  }

  validation {
    condition = alltrue([
      for group in values(var.node_groups) : contains(["ON_DEMAND", "SPOT"], group.capacity_type)
    ])
    error_message = "Each node group's capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "common_tags" {
  description = "Tags applied to resources that support tags."
  type        = map(string)
  default     = {}
}
