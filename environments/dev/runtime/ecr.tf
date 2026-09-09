module "ecr" {
  source = "../../../modules/ecr"

  repository_names = var.ecr_repository_names
  common_tags      = local.common_tags
}
