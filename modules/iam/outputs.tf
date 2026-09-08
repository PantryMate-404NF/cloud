output "cluster_role_arn" {
  description = "ARN of the EKS control-plane IAM role."
  value       = aws_iam_role.eks_cluster.arn
}

output "cluster_role_name" {
  description = "Name of the EKS control-plane IAM role."
  value       = aws_iam_role.eks_cluster.name
}

output "node_role_arn" {
  description = "ARN of the managed node group IAM role."
  value       = aws_iam_role.eks_node.arn
}

output "node_role_name" {
  description = "Name of the managed node group IAM role."
  value       = aws_iam_role.eks_node.name
}

