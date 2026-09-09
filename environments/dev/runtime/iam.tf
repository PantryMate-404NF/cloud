module "iam" {
  source = "../../../modules/iam"

  name_prefix = local.name_prefix
  common_tags = local.common_tags
}
