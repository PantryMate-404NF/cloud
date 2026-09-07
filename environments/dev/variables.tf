variable "region" {
  description = "AWS region in which resources are managed."
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Project identifier used in resource names and tags."
  type        = string
  default     = "pantry-mate"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name may contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment identifier."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment))
    error_message = "environment may contain only lowercase letters, numbers, and hyphens."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the DEV VPC."
  type        = string
}

variable "availability_zones" {
  description = "Availability zones used by the environment."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs ordered to match availability_zones."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs ordered to match availability_zones."
  type        = list(string)
}

variable "nat_instance_type" {
  description = "EC2 instance type used for each NAT instance."
  type        = string
  default     = "t3.nano"
}

variable "eks_cluster_name" {
  description = "Name of the DEV EKS cluster."
  type        = string
}

variable "eks_kubernetes_version" {
  description = "EKS Kubernetes minor version."
  type        = string

  validation {
    condition     = can(regex("^1\\.[0-9]+$", var.eks_kubernetes_version))
    error_message = "eks_kubernetes_version must be a minor version such as 1.35."
  }
}

variable "eks_endpoint_public_access" {
  description = "Expose the EKS Kubernetes API through a public endpoint."
  type        = bool
  default     = false
}

variable "eks_public_access_cidrs" {
  description = "CIDRs allowed to access the public Kubernetes API when enabled."
  type        = list(string)
  default     = []
}

variable "manage_node_instance_type" {
  description = "EC2 instance type for the management managed node group."
  type        = string
  default     = "t3.large"
}

variable "manage_node_capacity_type" {
  description = "Capacity type for the management managed node group."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.manage_node_capacity_type)
    error_message = "manage_node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "manage_node_min_size" {
  description = "Minimum management node count."
  type        = number
  default     = 1
}

variable "manage_node_max_size" {
  description = "Maximum management node count."
  type        = number
  default     = 1
}

variable "manage_node_desired_size" {
  description = "Desired management node count."
  type        = number
  default     = 1
}

variable "manage_node_labels" {
  description = "Kubernetes labels for the management managed node group."
  type        = map(string)
  default = {
    role = "manage"
  }
}

variable "worker_node_instance_type" {
  description = "EC2 instance type for the worker managed node group."
  type        = string
  default     = "t3.medium"
}

variable "worker_node_capacity_type" {
  description = "Capacity type for the worker managed node group."
  type        = string
  default     = "SPOT"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.worker_node_capacity_type)
    error_message = "worker_node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "worker_node_min_size" {
  description = "Minimum worker node count."
  type        = number
  default     = 3
}

variable "worker_node_max_size" {
  description = "Maximum worker node count."
  type        = number
  default     = 3
}

variable "worker_node_desired_size" {
  description = "Desired worker node count."
  type        = number
  default     = 3
}

variable "worker_node_labels" {
  description = "Kubernetes labels for the worker managed node group."
  type        = map(string)
  default = {
    role = "worker"
  }
}

variable "gpu_node_instance_type" {
  description = "GPU EC2 instance type for the GPU managed node group."
  type        = string
  default     = "g4dn.xlarge"
}

variable "gpu_node_min_size" {
  description = "Minimum GPU node count."
  type        = number
  default     = 0
}

variable "gpu_node_max_size" {
  description = "Maximum GPU node count."
  type        = number
  default     = 1
}

variable "gpu_node_desired_size" {
  description = "Desired GPU node count."
  type        = number
  default     = 0
}

variable "ecr_repository_names" {
  description = "ECR repositories created for this environment."
  type        = set(string)
}

variable "s3_bucket_name" {
  description = "Optional globally unique S3 bucket name. Null uses a project/environment/account-derived name."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.s3_bucket_name == null || can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.s3_bucket_name))
    error_message = "s3_bucket_name must be null or a valid 3-63 character lowercase S3 bucket name."
  }
}

variable "s3_versioning_enabled" {
  description = "Enable versioning on the shared S3 bucket."
  type        = bool
  default     = true
}

variable "cloudwatch_log_retention_days" {
  description = "Retention for EKS and application CloudWatch log groups."
  type        = number
  default     = 14
}

variable "extra_tags" {
  description = "Additional common tags applied to resources."
  type        = map(string)
  default     = {}
}
