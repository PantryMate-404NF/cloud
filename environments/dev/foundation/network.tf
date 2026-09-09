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

module "network" {
  source = "../../../modules/network"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  cluster_name         = var.eks_cluster_name
  common_tags          = local.common_tags
}
