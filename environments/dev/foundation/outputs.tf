output "vpc_id" {
  description = "DEV VPC ID."
  value       = module.network.vpc_id
}

output "vpc_cidr" {
  description = "DEV VPC CIDR used by lifecycle-independent security rules."
  value       = var.vpc_cidr
}

output "availability_zones" {
  description = "Availability zones used by DEV subnets."
  value       = var.availability_zones
}

output "public_subnet_ids" {
  description = "DEV public subnet IDs."
  value       = module.network.public_subnet_ids
}

output "public_subnet_ids_by_az" {
  description = "DEV public subnet IDs keyed by availability zone."
  value       = module.network.public_subnet_ids_by_az
}

output "private_subnet_ids" {
  description = "DEV private subnet IDs."
  value       = module.network.private_subnet_ids
}

output "private_subnet_ids_by_az" {
  description = "DEV private subnet IDs keyed by availability zone."
  value       = module.network.private_subnet_ids_by_az
}

output "private_subnet_cidrs" {
  description = "DEV private subnet CIDRs."
  value       = var.private_subnet_cidrs
}

output "private_route_table_ids_by_az" {
  description = "DEV private route-table IDs keyed by availability zone."
  value       = module.network.private_route_table_ids_by_az
}

output "rds_endpoint" {
  description = "DEV PostgreSQL endpoint hostname."
  value       = module.rds.endpoint
}

output "rds_port" {
  description = "DEV PostgreSQL port."
  value       = module.rds.port
}

output "rds_database_name" {
  description = "DEV initial PostgreSQL database name."
  value       = module.rds.database_name
}

output "rds_security_group_id" {
  description = "Security group attached to DEV RDS."
  value       = module.rds.security_group_id
}

output "rds_subnet_group_name" {
  description = "DEV RDS DB subnet group name."
  value       = module.rds.subnet_group_name
}

output "rds_availability_zone" {
  description = "Availability zone hosting the DEV database primary."
  value       = module.rds.availability_zone
}

output "rds_master_user_secret_arn" {
  description = "ARN of the RDS-managed master-user secret; no password is output."
  value       = module.rds.master_user_secret_arn
}
