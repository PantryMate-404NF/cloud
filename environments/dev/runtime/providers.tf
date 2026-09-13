provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}

# EKS 클러스터 인증 정보 — Jenkins/Helm 배포 시 필요
# EKS 클러스터가 먼저 생성된 이후에 아래 provider를 사용하는 모듈을 apply하세요.
data "aws_eks_cluster_auth" "this" {
  name = var.eks_cluster_name
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "github" {
  token = var.github_api_token
  owner = var.github_org
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
  load_config_file       = false
}
