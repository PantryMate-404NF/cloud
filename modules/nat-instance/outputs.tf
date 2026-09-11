output "instance_ids" {
  description = "NAT instance IDs in availability-zone key order."
  value       = [for az in sort(keys(aws_instance.this)) : aws_instance.this[az].id]
}

output "instance_ids_by_az" {
  description = "Map of availability zone to NAT instance ID."
  value       = { for az, instance in aws_instance.this : az => instance.id }
}

output "public_ips_by_az" {
  description = "Map of availability zone to NAT Elastic IP."
  value       = { for az, eip in aws_eip.this : az => eip.public_ip }
}

output "security_group_id" {
  description = "Security group ID shared by the NAT instances."
  value       = aws_security_group.this.id
}

output "ami_id" {
  description = "Canonical Ubuntu AMI ID used by the NAT instances."
  value       = data.aws_ami.ubuntu.id
}
