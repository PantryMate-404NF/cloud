# ── Argo CD 네임스페이스 ──────────────────────────────────────────────────────

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      name = "argocd"
    }
  }
}

# ── Argo CD Helm 설치 ─────────────────────────────────────────────────────────
# manage 노드에 배포, 외부 노출 없음 (Tailscale VPN / port-forward 접근)

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.7.23"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  timeout    = 600
  wait       = true

  values = [
    templatefile("${path.module}/values.yaml.tpl", {
      manage_node_label = var.manage_node_label
    })
  ]

  depends_on = [kubernetes_namespace.argocd]
}

# ── GitOps 레포 자격증명 ──────────────────────────────────────────────────────
# Argo CD가 GitOps 레포를 읽기 위한 credentials를 Secret으로 등록합니다.
# label: argocd.argoproj.io/secret-type=repository 가 있어야 Argo CD가 인식합니다.

resource "kubernetes_secret" "gitops_repo" {
  metadata {
    name      = "gitops-repo-credentials"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type     = "git"
    url      = var.gitops_repo_url
    username = var.github_org
    password = var.gitops_repo_token
  }

  depends_on = [helm_release.argocd]
}

# ── app 네임스페이스 ──────────────────────────────────────────────────────────

resource "kubernetes_namespace" "app" {
  metadata {
    name = var.app_namespace
    labels = {
      name = var.app_namespace
    }
  }
}

# ── Argo CD Application: frontend ────────────────────────────────────────────
# GitOps 레포의 environments/<env>/frontend 경로를 바라봅니다.

resource "kubernetes_manifest" "frontend_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = var.frontend_repo_name
      namespace = "argocd"
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = "HEAD"
        path           = "environments/${var.environment}/${var.frontend_repo_name}"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.app_namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=false",
          "PrunePropagationPolicy=foreground",
        ]
        retry = {
          limit = 5
          backoff = {
            duration    = "5s"
            factor      = 2
            maxDuration = "3m"
          }
        }
      }
    }
  }

  depends_on = [helm_release.argocd, kubernetes_secret.gitops_repo]
}

# ── Argo CD Application: backend ─────────────────────────────────────────────
# GitOps 레포의 environments/<env>/backend 경로를 바라봅니다.

resource "kubernetes_manifest" "backend_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = var.backend_repo_name
      namespace = "argocd"
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = "HEAD"
        path           = "environments/${var.environment}/${var.backend_repo_name}"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.app_namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=false",
          "PrunePropagationPolicy=foreground",
        ]
        retry = {
          limit = 5
          backoff = {
            duration    = "5s"
            factor      = 2
            maxDuration = "3m"
          }
        }
      }
    }
  }

  depends_on = [helm_release.argocd, kubernetes_secret.gitops_repo]
}
