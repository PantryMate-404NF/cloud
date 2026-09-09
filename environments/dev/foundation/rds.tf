check "rds_single_az_subnet" {
  assert {
    condition     = var.rds_multi_az || contains(var.availability_zones, var.rds_availability_zone)
    error_message = "rds_availability_zone must be included in availability_zones for a Single-AZ database."
  }
}

module "rds" {
  source = "../../../modules/rds"

  name_prefix        = local.name_prefix
  identifier         = var.rds_identifier
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  # A VPC-CIDR rule avoids a Foundation dependency on short-lived Runtime SG IDs.
  # Tighten this to a dedicated client SG after the EKS module supports attaching it.
  allowed_cidr_blocks = [var.vpc_cidr]

  engine_version        = var.rds_engine_version
  instance_class        = var.rds_instance_class
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  storage_type          = var.rds_storage_type

  database_name                 = var.rds_database_name
  master_username               = var.rds_master_username
  master_user_secret_kms_key_id = var.rds_master_user_secret_kms_key_id
  port                          = 5432
  multi_az                      = var.rds_multi_az
  availability_zone             = var.rds_availability_zone
  backup_retention_period       = var.rds_backup_retention_period
  deletion_protection           = var.rds_deletion_protection
  skip_final_snapshot           = var.rds_skip_final_snapshot
  final_snapshot_identifier     = var.rds_final_snapshot_identifier
  auto_minor_version_upgrade    = var.rds_auto_minor_version_upgrade
  apply_immediately             = var.rds_apply_immediately
  common_tags                   = local.common_tags
}
