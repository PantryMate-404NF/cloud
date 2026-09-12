check "manage_node_scaling" {
  assert {
    condition = (
      var.manage_node_min_size >= 0 &&
      var.manage_node_min_size <= var.manage_node_desired_size &&
      var.manage_node_desired_size <= var.manage_node_max_size &&
      var.manage_node_max_size >= 1
    )
    error_message = "Management node sizes must satisfy 0 <= min <= desired <= max and max >= 1."
  }
}

check "worker_node_scaling" {
  assert {
    condition = (
      var.worker_node_min_size >= 0 &&
      var.worker_node_min_size <= var.worker_node_desired_size &&
      var.worker_node_desired_size <= var.worker_node_max_size &&
      var.worker_node_max_size >= 1
    )
    error_message = "Worker node sizes must satisfy 0 <= min <= desired <= max and max >= 1."
  }
}

check "gpu_node_scaling" {
  assert {
    condition = (
      var.gpu_node_min_size >= 0 &&
      var.gpu_node_min_size <= var.gpu_node_desired_size &&
      var.gpu_node_desired_size <= var.gpu_node_max_size &&
      var.gpu_node_max_size >= 1
    )
    error_message = "GPU node sizes must satisfy 0 <= min <= desired <= max and max >= 1."
  }
}

data "aws_ssm_parameter" "ubuntu_eks_ami" {
  name = "/aws/service/canonical/ubuntu/eks/24.04/${var.eks_kubernetes_version}/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

data "aws_ami" "ubuntu_eks" {
  owners = ["099720109477"]

  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.ubuntu_eks_ami.value]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

module "eks" {
  source = "../../../modules/eks"

  cluster_name              = var.eks_cluster_name
  kubernetes_version        = var.eks_kubernetes_version
  cluster_role_arn          = module.iam.cluster_role_arn
  node_role_arn             = module.iam.node_role_arn
  ssh_key_name              = var.ec2_key_name
  node_ami_id               = data.aws_ami.ubuntu_eks.id
  node_ami_root_device_name = data.aws_ami.ubuntu_eks.root_device_name
  ssh_source_security_group_ids = [
    module.nat_instance.security_group_id,
  ]
  private_subnet_ids         = data.terraform_remote_state.foundation.outputs.private_subnet_ids
  endpoint_public_access     = var.eks_endpoint_public_access
  public_access_cidrs        = var.eks_public_access_cidrs
  cluster_log_retention_days = var.cloudwatch_log_retention_days
  common_tags                = local.common_tags

  node_groups = {
    manage = {
      instance_types = [var.manage_node_instance_type]
      min_size       = var.manage_node_min_size
      max_size       = var.manage_node_max_size
      desired_size   = var.manage_node_desired_size
      capacity_type  = var.manage_node_capacity_type
      disk_size      = 30
      labels         = var.manage_node_labels
    }
    worker = {
      instance_types = [var.worker_node_instance_type]
      min_size       = var.worker_node_min_size
      max_size       = var.worker_node_max_size
      desired_size   = var.worker_node_desired_size
      capacity_type  = var.worker_node_capacity_type
      disk_size      = 30
      labels         = var.worker_node_labels
    }
    gpu = {
      instance_types = [var.gpu_node_instance_type]
      min_size       = var.gpu_node_min_size
      max_size       = var.gpu_node_max_size
      desired_size   = var.gpu_node_desired_size
      capacity_type  = "ON_DEMAND"
      disk_size      = 50
      enable_nvidia  = true
      taints = [{
        key    = "nvidia.com/gpu"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
    }
  }

  depends_on = [module.iam, module.nat_instance]
}

# ── EKS OIDC Provider ─────────────────────────────────────────────────────────
# IRSA(IAM Roles for Service Accounts)에 필요합니다.
# jenkins 모듈 등 IRSA를 사용하는 모든 모듈에 arn/url을 전달합니다.

data "tls_certificate" "eks" {
  url = module.eks.oidc_issuer_url
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = module.eks.oidc_issuer_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-eks-oidc"
  })

  depends_on = [module.eks]
}

# ── Jenkins CI/CD ─────────────────────────────────────────────────────────────
# EKS manage 노드에 Jenkins 컨트롤러를, worker 노드에 빌드 에이전트를 배포합니다.
# 내부 NLB를 생성하여 Lambda webhook relay 및 VPN/배스천 접근에 사용합니다.
#
# 주의: EKS 클러스터가 완전히 준비된 후에 apply하세요.
#   terraform apply -target=module.iam -target=module.nat_instance -target=module.eks
#   terraform apply

module "jenkins" {
  source = "../../../modules/jenkins"

  name_prefix       = local.name_prefix
  eks_cluster_name  = var.eks_cluster_name
  oidc_provider_arn = aws_iam_openid_connect_provider.eks.arn
  oidc_provider_url = replace(module.eks.oidc_issuer_url, "https://", "")

  jenkins_admin_password = var.jenkins_admin_password
  github_webhook_secret  = var.github_webhook_secret
  github_api_token       = var.github_api_token

  github_org         = var.github_org
  frontend_repo_name = var.frontend_repo_name
  backend_repo_name  = var.backend_repo_name

  artifact_bucket_name = module.storage.bucket_name
  common_tags          = local.common_tags

  depends_on = [aws_iam_openid_connect_provider.eks, module.eks]
}

# ── GitHub Webhook Relay ──────────────────────────────────────────────────────
# GitHub → API Gateway(공개) → Lambda(VPC) → Jenkins 내부 NLB 흐름입니다.
# terraform output webhook_url 값을 각 레포지토리의 GitHub Webhook URL에 등록하세요.

module "webhook_relay" {
  source = "../../../modules/webhook-relay"

  name_prefix                    = local.name_prefix
  vpc_id                         = data.terraform_remote_state.foundation.outputs.vpc_id
  vpc_cidr                       = data.terraform_remote_state.foundation.outputs.vpc_cidr
  private_subnet_ids             = data.terraform_remote_state.foundation.outputs.private_subnet_ids
  eks_cluster_security_group_id  = module.eks.cluster_security_group_id
  jenkins_internal_url           = module.jenkins.jenkins_internal_url
  github_webhook_secret_ssm_name = module.jenkins.github_webhook_secret_ssm_name
  common_tags                    = local.common_tags

  depends_on = [module.jenkins]
}

# ── GitHub Webhook 자동 등록 ──────────────────────────────────────────────────
# terraform apply 시 API Gateway URL을 각 레포에 자동 등록합니다.
# destroy 후 재apply 시에도 새 URL로 자동 교체됩니다.

resource "github_repository_webhook" "frontend" {
  repository = var.frontend_repo_name
  configuration {
    url          = module.webhook_relay.webhook_url
    content_type = "json"
    secret       = var.github_webhook_secret
  }
  events = ["push"]
}

resource "github_repository_webhook" "backend" {
  repository = var.backend_repo_name
  configuration {
    url          = module.webhook_relay.webhook_url
    content_type = "json"
    secret       = var.github_webhook_secret
  }
  events = ["push"]
}
