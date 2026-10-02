resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = merge(var.common_tags, {
    Name = var.bucket_name
  })
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# 고객 관리형 키(CMK). 버킷에 접근하는 주체는 kms:Decrypt, kms:GenerateDataKey 권한이 필요하다.
resource "aws_kms_key" "this" {
  description             = "${var.bucket_name} S3 encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = merge(var.common_tags, {
    Name = "${var.bucket_name}-s3"
  })
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.bucket_name}-s3"
  target_key_id = aws_kms_key.this.key_id
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.this.arn
    }

    bucket_key_enabled = true
  }
}

