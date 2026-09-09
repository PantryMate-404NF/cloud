module "observability" {
  source = "../../../modules/observability"

  name_prefix        = local.name_prefix
  log_retention_days = var.cloudwatch_log_retention_days
  common_tags        = local.common_tags
}
