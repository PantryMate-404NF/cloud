### EKS Pod Identity
resource "aws_eks_addon" "pod_identity_agent" {
  count = var.manage_pod_identity_agent ? 1 : 0

  cluster_name = var.cluster_name
  addon_name   = "eks-pod-identity-agent"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}