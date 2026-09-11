# ── EBS CSI Driver ────────────────────────────────────────────────────────────
# Jenkins 컨트롤러의 영구 볼륨(PVC)을 위해 EBS CSI 드라이버를 활성화합니다.

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.name_prefix}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json
  tags               = var.common_tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = var.eks_cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi.arn

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-ebs-csi-addon"
  })

  depends_on = [aws_iam_role_policy_attachment.ebs_csi]
}

# ── Jenkins IRSA ──────────────────────────────────────────────────────────────
# Jenkins 파드가 ECR push/pull, EKS describe, S3 artifact 저장에 사용할 IAM Role

data "aws_iam_policy_document" "jenkins_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:jenkins"]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "jenkins" {
  name               = "${var.name_prefix}-jenkins"
  assume_role_policy = data.aws_iam_policy_document.jenkins_assume_role.json
  tags               = var.common_tags
}

data "aws_iam_policy_document" "jenkins" {
  # ECR 인증 토큰 (계정 레벨)
  statement {
    sid       = "ECRAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # ECR 이미지 push/pull (프로젝트 레포지토리만)
  statement {
    sid    = "ECRRepository"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
    ]
    resources = ["arn:aws:ecr:*:*:repository/${var.name_prefix}-*"]
  }

  # EKS 클러스터 정보 조회 (kubectl용)
  statement {
    sid       = "EKSDescribe"
    effect    = "Allow"
    actions   = ["eks:DescribeCluster"]
    resources = ["*"]
  }

  # S3 빌드 아티팩트 저장
  statement {
    sid    = "S3Artifacts"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${var.artifact_bucket_name}",
      "arn:aws:s3:::${var.artifact_bucket_name}/*",
    ]
  }
}

resource "aws_iam_role_policy" "jenkins" {
  name   = "jenkins-policy"
  role   = aws_iam_role.jenkins.id
  policy = data.aws_iam_policy_document.jenkins.json
}

# ── SSM Parameters ────────────────────────────────────────────────────────────
# 민감한 값은 SSM Parameter Store에 저장하여 Lambda와 Jenkins가 런타임에 읽습니다.

resource "aws_ssm_parameter" "github_webhook_secret" {
  name  = "/${var.name_prefix}/jenkins/github-webhook-secret"
  type  = "SecureString"
  value = var.github_webhook_secret
  tags  = var.common_tags
}

resource "aws_ssm_parameter" "github_api_token" {
  name  = "/${var.name_prefix}/jenkins/github-api-token"
  type  = "SecureString"
  value = var.github_api_token
  tags  = var.common_tags
}

# ── Kubernetes Namespace ──────────────────────────────────────────────────────

resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = var.namespace
    labels = {
      name = var.namespace
    }
  }
}

# ── Jenkins Helm Release ──────────────────────────────────────────────────────
# jenkins/jenkins 차트를 사용합니다.
# JCasC로 파이프라인 2개(frontend, backend)를 자동 생성합니다.

resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  version    = "5.8.10"
  namespace  = kubernetes_namespace.jenkins.metadata[0].name
  timeout    = 600
  wait       = true

  values = [
    templatefile("${path.module}/values.yaml.tpl", {
      jenkins_role_arn      = aws_iam_role.jenkins.arn
      namespace             = var.namespace
      eks_cluster_name      = var.eks_cluster_name
      name_prefix           = var.name_prefix
      manage_node_label     = var.manage_node_label
      worker_node_label     = var.worker_node_label
      github_org            = var.github_org
      frontend_repo_name    = var.frontend_repo_name
      backend_repo_name     = var.backend_repo_name
      github_api_token      = var.github_api_token
      github_webhook_secret = var.github_webhook_secret
    })
  ]

  set_sensitive {
    name  = "controller.admin.password"
    value = var.jenkins_admin_password
  }

  depends_on = [
    kubernetes_namespace.jenkins,
    aws_eks_addon.ebs_csi,
  ]
}

# ── Jenkins 내부 NLB 주소 조회 ────────────────────────────────────────────────
# helm_release 완료 후 Kubernetes가 프로비저닝한 내부 NLB 호스트네임을 읽습니다.
# Lambda webhook relay가 이 URL로 요청을 전달합니다.

data "kubernetes_service" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = var.namespace
  }
  depends_on = [helm_release.jenkins]
}
