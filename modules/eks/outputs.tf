output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded Kubernetes API certificate authority data."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security group created by EKS for the cluster."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for future workload IAM integration."
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "node_group_names" {
  description = "Managed node group names keyed by logical role."
  value       = { for role, group in aws_eks_node_group.this : role => group.node_group_name }
}

output "cluster_log_group_name" {
  description = "CloudWatch Logs group containing EKS control-plane logs."
  value       = aws_cloudwatch_log_group.cluster.name
}

output "node_ami_id" {
  description = "Canonical Ubuntu EKS AMI ID used by the managed node groups."
  value       = var.node_ami_id
}

output "node_launch_template_ids" {
  description = "EC2 launch template IDs keyed by managed node group role."
  value       = { for role, template in aws_launch_template.node : role => template.id }
}
