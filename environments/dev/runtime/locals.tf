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
