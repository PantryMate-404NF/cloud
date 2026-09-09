module "storage" {
  source = "../../../modules/storage"

  bucket_name        = local.s3_bucket_name
  versioning_enabled = var.s3_versioning_enabled
  common_tags        = local.common_tags
}
