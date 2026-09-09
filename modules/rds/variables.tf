variable "name_prefix" {
  description = "Prefix used for RDS-related resource names."
  type        = string
}

variable "identifier" {
  description = "RDS DB instance identifier."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC containing the database."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs spanning at least two availability zones."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "private_subnet_ids must contain at least two subnets for an RDS DB subnet group."
  }
}

variable "allowed_cidr_blocks" {
  description = "IPv4 CIDR blocks allowed to connect to PostgreSQL."
  type        = set(string)

  validation {
    condition = (
      length(var.allowed_cidr_blocks) > 0 &&
      alltrue([for cidr in var.allowed_cidr_blocks : can(cidrnetmask(cidr)) && cidr != "0.0.0.0/0"])
    )
    error_message = "Provide at least one valid client CIDR; 0.0.0.0/0 is prohibited."
  }
}

variable "engine_version" {
  description = "PostgreSQL engine version supported by RDS in the target region."
  type        = string
}

variable "instance_class" {
  description = "RDS DB instance class."
  type        = string
}

variable "allocated_storage" {
  description = "Initial storage allocation in GiB."
  type        = number
}

variable "max_allocated_storage" {
  description = "Maximum autoscaled storage allocation in GiB."
  type        = number
}

variable "storage_type" {
  description = "RDS storage type."
  type        = string
  default     = "gp3"
}

variable "database_name" {
  description = "Name of the initial PostgreSQL database."
  type        = string
}

variable "master_username" {
  description = "PostgreSQL master username; the password is managed by RDS in Secrets Manager."
  type        = string
}

variable "master_user_secret_kms_key_id" {
  description = "Optional KMS key ARN for the RDS-managed master-user secret. Null uses the AWS managed key."
  type        = string
  default     = null
  nullable    = true
}

variable "port" {
  description = "PostgreSQL listener port."
  type        = number
  default     = 5432
}

variable "multi_az" {
  description = "Whether to deploy a Multi-AZ DB instance."
  type        = bool
}

variable "availability_zone" {
  description = "Availability zone for a Single-AZ instance. Ignored when multi_az is true."
  type        = string
  default     = null
  nullable    = true
}

variable "backup_retention_period" {
  description = "Automated backup retention in days."
  type        = number

  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "backup_retention_period must be between 0 and 35 days."
  }
}

variable "deletion_protection" {
  description = "Whether RDS deletion protection is enabled."
  type        = bool
}

variable "skip_final_snapshot" {
  description = "Whether to skip a final snapshot when the DB instance is deleted."
  type        = bool
}

variable "final_snapshot_identifier" {
  description = "Final snapshot identifier, required when skip_final_snapshot is false."
  type        = string
  default     = null
  nullable    = true
}

variable "auto_minor_version_upgrade" {
  description = "Allow automatic PostgreSQL minor-version upgrades."
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Apply RDS modifications immediately instead of during the maintenance window."
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Tags applied to RDS resources."
  type        = map(string)
  default     = {}
}
