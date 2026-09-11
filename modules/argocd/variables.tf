variable "name_prefix" {
  description = "Resource name prefix (project-environment)."
  type        = string
}

variable "manage_node_label" {
  description = "Kubernetes node label value for the manage node group."
  type        = string
  default     = "manage"
}

variable "gitops_repo_url" {
  description = "GitOps 레포지토리 HTTPS URL. Argo CD가 매니페스트를 읽어오는 레포입니다."
  type        = string
}

variable "gitops_repo_token" {
  description = "GitOps 레포지토리 접근에 사용할 GitHub Personal Access Token."
  type        = string
  sensitive   = true
}

variable "github_org" {
  description = "GitHub 조직명 또는 계정명 (GitOps 레포 소유자)."
  type        = string
}

variable "frontend_repo_name" {
  description = "프론트엔드 앱 이름 (Argo CD Application 이름 및 GitOps 경로에 사용)."
  type        = string
}

variable "backend_repo_name" {
  description = "백엔드 앱 이름 (Argo CD Application 이름 및 GitOps 경로에 사용)."
  type        = string
}

variable "environment" {
  description = "배포 환경 (dev/prod). GitOps 레포 내 경로 구분에 사용됩니다."
  type        = string
  default     = "dev"
}

variable "app_namespace" {
  description = "frontend/backend Pod가 배포될 Kubernetes 네임스페이스."
  type        = string
  default     = "app"
}

variable "common_tags" {
  description = "모든 리소스에 공통으로 적용할 태그."
  type        = map(string)
  default     = {}
}
