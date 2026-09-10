check "manage_node_scaling" {
  assert {
    condition = (
      var.manage_node_min_size >= 0 &&
      var.manage_node_min_size <= var.manage_node_desired_size &&
      var.manage_node_desired_size <= var.manage_node_max_size &&
      var.manage_node_max_size >= 1
    )
    error_message = "Management node sizes must satisfy 0 <= min <= desired <= max and max >= 1."
  }
}

check "worker_node_scaling" {
  assert {
    condition = (
      var.worker_node_min_size >= 0 &&
      var.worker_node_min_size <= var.worker_node_desired_size &&
      var.worker_node_desired_size <= var.worker_node_max_size &&
      var.worker_node_max_size >= 1
    )
    error_message = "Worker node sizes must satisfy 0 <= min <= desired <= max and max >= 1."
  }
}

check "gpu_node_scaling" {
  assert {
    condition = (
      var.gpu_node_min_size >= 0 &&
      var.gpu_node_min_size <= var.gpu_node_desired_size &&
      var.gpu_node_desired_size <= var.gpu_node_max_size &&
      var.gpu_node_max_size >= 1
    )
    error_message = "GPU node sizes must satisfy 0 <= min <= desired <= max and max >= 1."
  }
}

module "eks" {
  source = "../../../modules/eks"

  cluster_name       = var.eks_cluster_name
  kubernetes_version = var.eks_kubernetes_version
  cluster_role_arn   = module.iam.cluster_role_arn
  node_role_arn      = module.iam.node_role_arn
  ssh_key_name       = var.ec2_key_name
  ssh_source_security_group_ids = [
    module.nat_instance.security_group_id,
  ]
  private_subnet_ids         = data.terraform_remote_state.foundation.outputs.private_subnet_ids
  endpoint_public_access     = var.eks_endpoint_public_access
  public_access_cidrs        = var.eks_public_access_cidrs
  cluster_log_retention_days = var.cloudwatch_log_retention_days
  common_tags                = local.common_tags

  node_groups = {
    manage = {
      instance_types = [var.manage_node_instance_type]
      min_size       = var.manage_node_min_size
      max_size       = var.manage_node_max_size
      desired_size   = var.manage_node_desired_size
      capacity_type  = var.manage_node_capacity_type
      ami_type       = "AL2023_x86_64_STANDARD"
      disk_size      = 30
      labels         = var.manage_node_labels
    }
    worker = {
      instance_types = [var.worker_node_instance_type]
      min_size       = var.worker_node_min_size
      max_size       = var.worker_node_max_size
      desired_size   = var.worker_node_desired_size
      capacity_type  = var.worker_node_capacity_type
      ami_type       = "AL2023_x86_64_STANDARD"
      disk_size      = 30
      labels         = var.worker_node_labels
    }
    gpu = {
      instance_types = [var.gpu_node_instance_type]
      min_size       = var.gpu_node_min_size
      max_size       = var.gpu_node_max_size
      desired_size   = var.gpu_node_desired_size
      capacity_type  = "SPOT"
      ami_type       = "AL2023_x86_64_NVIDIA"
      disk_size      = 50
      taints = [{
        key    = "nvidia.com/gpu"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
    }
  }

  depends_on = [module.iam, module.nat_instance]
}
