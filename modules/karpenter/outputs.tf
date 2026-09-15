output "controller_role_arn" {
  value = module.karpenter_aws.iam_role_arn
}

output "node_role_arn" {
  value = module.karpenter_aws.node_iam_role_arn
}

output "node_role_name" {
  value = module.karpenter_aws.node_iam_role_name
}

output "interruption_queue_name" {
  value = module.karpenter_aws.queue_name
}