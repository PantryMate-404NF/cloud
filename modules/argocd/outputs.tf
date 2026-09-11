output "argocd_namespace" {
  description = "Argo CD가 설치된 Kubernetes 네임스페이스."
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_port_forward_command" {
  description = "로컬에서 Argo CD UI에 접근하기 위한 kubectl port-forward 명령어."
  value       = "kubectl port-forward svc/argocd-server -n argocd 8080:80"
}

output "frontend_app_name" {
  description = "Argo CD Application 이름 (frontend)."
  value       = var.frontend_repo_name
}

output "backend_app_name" {
  description = "Argo CD Application 이름 (backend)."
  value       = var.backend_repo_name
}
