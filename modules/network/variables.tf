variable "name_prefix" {
  description = "Prefix used for resource names."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "Availability zones used by the public and private subnets."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs, ordered to match availability_zones."
  type        = list(string)

  validation {
    condition     = alltrue([for cidr in var.public_subnet_cidrs : can(cidrnetmask(cidr))])
    error_message = "Every public subnet CIDR must be valid."
  }
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs, ordered to match availability_zones."
  type        = list(string)

  validation {
    condition     = alltrue([for cidr in var.private_subnet_cidrs : can(cidrnetmask(cidr))])
    error_message = "Every private subnet CIDR must be valid."
  }
}

variable "cluster_name" {
  description = "EKS cluster name used for Kubernetes subnet discovery tags."
  type        = string
}

variable "common_tags" {
  description = "Tags applied to resources that support tags."
  type        = map(string)
  default     = {}
}

