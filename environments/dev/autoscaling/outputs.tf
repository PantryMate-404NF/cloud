output "cluster_name" {
  value = var.cluster_name
}

output "keda_namespace" {
  value = module.keda.namespace
}

output "karpenter_controller_role_arn" {
  value = module.karpenter.controller_role_arn
}

output "karpenter_node_role_arn" {
  value = module.karpenter.node_role_arn
}

output "karpenter_interruption_queue" {
  value = module.karpenter.interruption_queue_name
}
output "items_bucket_name" {
  value = data.aws_s3_bucket.items.id
}

output "items_s3_role_arn" {
  value = aws_iam_role.items_s3.arn
}
