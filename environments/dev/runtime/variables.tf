variable "region" {
  description = "AWS region in which Runtime resources are managed."
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
    condition     = var.environment == "dev"
    error_message = "This root module manages only the dev environment."
  }
}

variable "terraform_state_bucket_name" {
  description = "Bootstrap S3 bucket containing the Foundation State."
  type        = string
}

variable "foundation_state_key" {
  description = "S3 object key for the DEV Foundation State."
  type        = string
  default     = "dev/foundation/terraform.tfstate"
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
  description = "Additional common tags applied to Runtime resources."
  type        = map(string)
  default     = {}
}

# ── Jenkins CI/CD ─────────────────────────────────────────────────────────────

variable "jenkins_admin_password" {
  description = "Jenkins admin 계정 비밀번호."
  type        = string
  sensitive   = true
}

variable "github_webhook_secret" {
  description = "GitHub webhook 페이로드 서명 검증에 사용할 공유 시크릿 (HMAC-SHA256)."
  type        = string
  sensitive   = true
}

variable "github_api_token" {
  description = "Jenkins가 GitHub 레포지토리 클론 및 API 호출에 사용할 Personal Access Token."
  type        = string
  sensitive   = true
}

variable "github_org" {
  description = "소스 레포지토리를 보유한 GitHub 조직명 또는 계정명."
  type        = string
}

variable "frontend_repo_name" {
  description = "프론트엔드 서비스의 GitHub 레포지토리 이름."
  type        = string
}

variable "backend_repo_name" {
  description = "백엔드 서비스의 GitHub 레포지토리 이름."
  type        = string
}
