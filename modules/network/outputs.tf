output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs in availability_zones order."
  value       = [for az in var.availability_zones : aws_subnet.public[az].id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs in availability_zones order."
  value       = [for az in var.availability_zones : aws_subnet.private[az].id]
}

output "public_subnet_ids_by_az" {
  description = "Map of availability zone to public subnet ID."
  value       = { for az, subnet in aws_subnet.public : az => subnet.id }
}

output "private_subnet_ids_by_az" {
  description = "Map of availability zone to private subnet ID."
  value       = { for az, subnet in aws_subnet.private : az => subnet.id }
}

output "private_route_table_ids_by_az" {
  description = "Map of availability zone to private route table ID."
  value       = { for az, route_table in aws_route_table.private : az => route_table.id }
}

