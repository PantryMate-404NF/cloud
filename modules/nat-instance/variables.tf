variable "name_prefix" {
  description = "Prefix used for resource names."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC containing the NAT instances."
  type        = string
}

variable "public_subnet_ids_by_az" {
  description = "Map of availability zone to public subnet ID."
  type        = map(string)
}

variable "private_route_table_ids_by_az" {
  description = "Map of availability zone to private route table ID."
  type        = map(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs allowed to forward traffic through the NAT instances."
  type        = set(string)
}

variable "instance_type" {
  description = "EC2 instance type for each NAT instance."
  type        = string
  default     = "t3.nano"
}

variable "ami_ssm_parameter_name" {
  description = "Public SSM parameter that resolves to the current Amazon Linux 2023 AMI."
  type        = string
  default     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

variable "root_volume_size" {
  description = "NAT instance root volume size in GiB."
  type        = number
  default     = 8
}

variable "common_tags" {
  description = "Tags applied to resources that support tags."
  type        = map(string)
  default     = {}
}

