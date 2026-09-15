module "keda" {
  source = "../../../modules/keda"

  namespace     = "keda"
  chart_version = "2.20.2"

  depends_on = [
    helm_release.metrics_server
  ]
}

module "karpenter" {
  source = "../../../modules/karpenter"

  cluster_name = var.cluster_name

  private_subnet_ids = tolist(
    data.aws_eks_cluster.this.vpc_config[0].subnet_ids
  )

  cluster_security_group_id = (
    data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  )

  instance_types = [
    "t3.medium",
    "t3.large",
    "m5.large",
    "m6i.large"
  ]

  capacity_types = [
    "spot"
  ]

  cpu_limit = "16"

  tags = var.common_tags

  depends_on = [
    aws_eks_addon.pod_identity_agent
  ]
}