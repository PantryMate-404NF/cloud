### 앱 이미지 버킷 접근 (EKS Pod Identity)
# 버킷은 콘솔에서 수동 생성했으므로 data 소스로 참조만 합니다.
# 버킷은 private(Block Public Access) 유지, 접근은 아래 Role을 받은 파드만 가능합니다.
data "aws_s3_bucket" "items" {
  bucket = var.items_bucket_name
}

data "aws_iam_policy_document" "items_s3_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
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

resource "aws_iam_role" "items_s3" {
  name               = "${var.cluster_name}-items-s3"
  assume_role_policy = data.aws_iam_policy_document.items_s3_trust.json
}

resource "aws_iam_role_policy" "items_s3" {
  name   = "items-s3-access"
  role   = aws_iam_role.items_s3.id
  policy = data.aws_iam_policy_document.items_s3.json
}

# ServiceAccount는 gitops 레포에서 생성합니다. association은 SA보다 먼저 만들어도 됩니다.
resource "aws_eks_pod_identity_association" "items_s3" {
  for_each = toset(var.items_s3_service_accounts)

  cluster_name    = var.cluster_name
  namespace       = var.app_namespace
  service_account = each.value
  role_arn        = aws_iam_role.items_s3.arn

  depends_on = [
    aws_eks_addon.pod_identity_agent
  ]
}
