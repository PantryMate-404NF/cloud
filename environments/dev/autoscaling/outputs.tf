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