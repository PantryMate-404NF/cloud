# ── Cloudflare Tunnel (cloudflared) ──────────────────────────────────────────
# Cloudflare Zero Trust 터널을 통해 ArgoCD/Jenkins UI를 외부에 노출합니다.

resource "kubernetes_namespace" "cloudflare" {
  metadata {
    name = "cloudflare"
    labels = {
      name = "cloudflare"
    }
  }
}

resource "kubernetes_secret" "cloudflared_token" {
  metadata {
    name      = "cloudflared-token"
    namespace = kubernetes_namespace.cloudflare.metadata[0].name
  }

  data = {
    TUNNEL_TOKEN = var.cloudflared_tunnel_token
  }

  type = "Opaque"
}

resource "kubernetes_deployment" "cloudflared" {
  metadata {
    name      = "cloudflared"
    namespace = kubernetes_namespace.cloudflare.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "cloudflared"
      }
    }

    template {
      metadata {
        labels = {
          app = "cloudflared"
        }
      }

      spec {
        node_selector = {
          role = "manage"
        }

        container {
          name  = "cloudflared"
          image = "cloudflare/cloudflared:latest"

          args = [
            "tunnel",
            "--no-autoupdate",
            "run",
            "--token",
            "$(TUNNEL_TOKEN)",
          ]

          env {
            name = "TUNNEL_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.cloudflared_token.metadata[0].name
                key  = "TUNNEL_TOKEN"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_secret.cloudflared_token]
}
