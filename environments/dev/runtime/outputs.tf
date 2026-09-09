output "vpc_id" {
  description = "DEV VPC ID read from Foundation State."
  value       = data.terraform_remote_state.foundation.outputs.vpc_id
}

output "public_subnet_ids" {
  description = "DEV public subnet IDs read from Foundation State."
  value       = data.terraform_remote_state.foundation.outputs.public_subnet_ids
}

output "private_subnet_ids" {
  description = "DEV private subnet IDs read from Foundation State."
  value       = data.terraform_remote_state.foundation.outputs.private_subnet_ids
}

output "nat_instance_ids" {
  description = "NAT instance IDs, one per availability zone."
  value       = module.nat_instance.instance_ids
}

output "nat_public_ips_by_az" {
  description = "NAT Elastic IPs keyed by availability zone."
  value       = module.nat_instance.public_ips_by_az
}

output "eks_cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id" {
  description = "EKS-managed cluster security group ID."
  value       = module.eks.cluster_security_group_id
}

output "eks_oidc_issuer_url" {
  description = "OIDC issuer URL for future workload IAM configuration."
  value       = module.eks.oidc_issuer_url
}

output "manage_node_group_name" {
  description = "Management managed node group name."
  value       = module.eks.node_group_names["manage"]
}

output "worker_node_group_name" {
  description = "Worker managed node group name."
  value       = module.eks.node_group_names["worker"]
}

output "gpu_node_group_name" {
  description = "GPU managed node group name."
  value       = module.eks.node_group_names["gpu"]
}

output "ecr_repository_urls" {
  description = "ECR repository URLs keyed by name."
  value       = module.ecr.repository_urls
}

output "s3_bucket_name" {
  description = "Shared S3 bucket name."
  value       = module.storage.bucket_name
}

output "eks_control_plane_log_group_name" {
  description = "CloudWatch log group for EKS control-plane logs."
  value       = module.eks.cluster_log_group_name
}

output "application_log_group_name" {
  description = "Shared CloudWatch application log group for future collectors."
  value       = module.observability.application_log_group_name
}

output "kubeconfig_update_command" {
  description = "Command for configuring kubectl after network access and AWS permissions are available."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}
