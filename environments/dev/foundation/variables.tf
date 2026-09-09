variable "region" {
  description = "AWS region in which Foundation resources are managed."
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

variable "eks_cluster_name" {
  description = "EKS cluster name retained on subnet discovery tags."
  type        = string
}

variable "rds_identifier" {
  description = "DEV PostgreSQL RDS instance identifier."
  type        = string
  default     = "pantry-mate-dev-postgres"
}

variable "rds_engine_version" {
  description = "PostgreSQL version currently supported by RDS in ap-northeast-2."
  type        = string
}

variable "rds_instance_class" {
  description = "DEV RDS DB instance class."
  type        = string
  default     = "db.t4g.medium"
}

variable "rds_allocated_storage" {
  description = "Initial DEV RDS storage in GiB."
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage" {
  description = "Maximum autoscaled DEV RDS storage in GiB."
  type        = number
  default     = 100
}

variable "rds_storage_type" {
  description = "DEV RDS storage type."
  type        = string
  default     = "gp3"
}

variable "rds_database_name" {
  description = "Initial PostgreSQL database name."
  type        = string
  default     = "pantry_mate"
}

variable "rds_master_username" {
  description = "PostgreSQL master username. The password is managed by RDS."
  type        = string
  default     = "pantryadmin"
}

variable "rds_master_user_secret_kms_key_id" {
  description = "Optional KMS key ARN for the RDS-managed master password secret."
  type        = string
  default     = null
  nullable    = true
}

variable "rds_multi_az" {
  description = "Whether the DEV database is Multi-AZ."
  type        = bool
  default     = false
}

variable "rds_availability_zone" {
  description = "Availability zone for the Single-AZ DEV database."
  type        = string
  default     = "ap-northeast-2a"
}

variable "rds_backup_retention_period" {
  description = "DEV automated backup retention in days."
  type        = number
  default     = 1
}

variable "rds_deletion_protection" {
  description = "Whether DEV RDS deletion protection is enabled."
  type        = bool
  default     = false
}

variable "rds_skip_final_snapshot" {
  description = "Whether to skip a final snapshot when deleting DEV RDS."
  type        = bool
  default     = true
}

variable "rds_final_snapshot_identifier" {
  description = "Required final snapshot identifier when rds_skip_final_snapshot is false."
  type        = string
  default     = null
  nullable    = true
}

variable "rds_auto_minor_version_upgrade" {
  description = "Allow automatic PostgreSQL minor-version upgrades."
  type        = bool
  default     = true
}

variable "rds_apply_immediately" {
  description = "Apply RDS modifications immediately rather than in a maintenance window."
  type        = bool
  default     = false
}

variable "extra_tags" {
  description = "Additional common tags applied to Foundation resources."
  type        = map(string)
  default     = {}
}
