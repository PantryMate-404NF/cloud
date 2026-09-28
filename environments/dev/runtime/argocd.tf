# ── Argo CD (GitOps CD) ───────────────────────────────────────────────────────
# GitOps 레포를 polling하여 EKS 클러스터 상태를 자동으로 동기화합니다.
# UI 접근: kubectl port-forward svc/argocd-server -n argocd 8080:80 (Tailscale 경유)
#
# 주의: Jenkins + webhook_relay가 apply된 이후에 apply하세요.
#   terraform apply -target=module.argocd

module "argocd" {
  source = "../../../modules/argocd"

  manage_node_label  = var.manage_node_labels["role"]
  gitops_repo_url    = var.gitops_repo_url
  gitops_repo_token  = var.gitops_repo_token
  github_org         = var.github_org
  frontend_repo_name = var.frontend_repo_name
  backend_repo_name  = var.backend_repo_name
  ai_repo_name       = var.ai_repo_name
  environment        = var.environment

  frontend_gitops_path = var.frontend_gitops_path
  backend_gitops_path  = var.backend_gitops_path
  ai_gitops_path       = var.ai_gitops_path
  app_namespace        = var.app_namespace

  depends_on = [module.eks]
}
