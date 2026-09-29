### 앱 이미지 버킷 접근 (IAM User Access Key)
# 버킷은 콘솔에서 수동 생성했으므로 data 소스로 참조만 합니다.
# Access Key는 state에 시크릿이 남지 않도록 Terraform 밖(CLI)에서 발급해
# backend-secrets / ai-secrets 에 AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY 로 넣습니다.
data "aws_s3_bucket" "items" {
  bucket = var.items_bucket_name
}

data "aws_iam_policy_document" "items_s3" {
  statement {
    sid       = "ListBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [data.aws_s3_bucket.items.arn]
  }

  statement {
    sid    = "ObjectReadWrite"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = ["${data.aws_s3_bucket.items.arn}/*"]
  }
}

resource "aws_iam_user" "items_s3" {
  name = "${var.cluster_name}-items-s3"
}

resource "aws_iam_user_policy" "items_s3" {
  name   = "items-s3-access"
  user   = aws_iam_user.items_s3.name
  policy = data.aws_iam_policy_document.items_s3.json
}
