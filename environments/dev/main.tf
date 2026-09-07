data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = merge(var.extra_tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })

  s3_bucket_name = coalesce(
    var.s3_bucket_name,
    "${local.name_prefix}-infra-${data.aws_caller_identity.current.account_id}"
  )
}

check "subnet_list_lengths" {
  assert {
    condition = (
      length(var.availability_zones) >= 2 &&
      length(var.availability_zones) == length(var.public_subnet_cidrs) &&
      length(var.availability_zones) == length(var.private_subnet_cidrs)
    )
    error_message = "Provide at least two availability zones and exactly one public/private subnet CIDR per zone."
  }
}

check "unique_network_values" {
  assert {
    condition = (
      length(distinct(var.availability_zones)) == length(var.availability_zones) &&
      length(distinct(concat(var.public_subnet_cidrs, var.private_subnet_cidrs))) ==
      length(concat(var.public_subnet_cidrs, var.private_subnet_cidrs))
    )
    error_message = "Availability zones and subnet CIDRs must not contain duplicates."
  }
}

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

module "network" {
  source = "../../modules/network"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  cluster_name         = var.eks_cluster_name
  common_tags          = local.common_tags
}

module "nat_instance" {
  source = "../../modules/nat-instance"

  name_prefix                   = local.name_prefix
  vpc_id                        = module.network.vpc_id
  public_subnet_ids_by_az       = module.network.public_subnet_ids_by_az
  private_route_table_ids_by_az = module.network.private_route_table_ids_by_az
  private_subnet_cidrs          = toset(var.private_subnet_cidrs)
  instance_type                 = var.nat_instance_type
  common_tags                   = local.common_tags
}

module "iam" {
  source = "../../modules/iam"

  name_prefix = local.name_prefix
  common_tags = local.common_tags
}

module "eks" {
  source = "../../modules/eks"

  cluster_name               = var.eks_cluster_name
  kubernetes_version         = var.eks_kubernetes_version
  cluster_role_arn           = module.iam.cluster_role_arn
  node_role_arn              = module.iam.node_role_arn
  private_subnet_ids         = module.network.private_subnet_ids
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

module "ecr" {
  source = "../../modules/ecr"

  repository_names = var.ecr_repository_names
  common_tags      = local.common_tags
}

module "storage" {
  source = "../../modules/storage"

  bucket_name        = local.s3_bucket_name
  versioning_enabled = var.s3_versioning_enabled
  common_tags        = local.common_tags
}

module "observability" {
  source = "../../modules/observability"

  name_prefix        = local.name_prefix
  log_retention_days = var.cloudwatch_log_retention_days
  common_tags        = local.common_tags
}
