output "endpoint" {
  description = "PostgreSQL endpoint hostname."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "PostgreSQL listener port."
  value       = aws_db_instance.this.port
}

output "database_name" {
  description = "Name of the initial PostgreSQL database."
  value       = aws_db_instance.this.db_name
}

output "security_group_id" {
  description = "Security group attached to the RDS instance."
  value       = aws_security_group.this.id
}

output "subnet_group_name" {
  description = "RDS DB subnet group name."
  value       = aws_db_subnet_group.this.name
}

output "availability_zone" {
  description = "Availability zone hosting the primary DB instance."
  value       = aws_db_instance.this.availability_zone
}

output "master_user_secret_arn" {
  description = "ARN of the RDS-managed Secrets Manager secret. The password is never output."
  value       = try(aws_db_instance.this.master_user_secret[0].secret_arn, null)
}
