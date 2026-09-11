output "jenkins_internal_url" {
  description = "Jenkins 내부 NLB URL. Lambda webhook relay 및 VPN/배스천 접근에 사용됩니다."
  value       = "http://${data.kubernetes_service.jenkins.status[0].load_balancer[0].ingress[0].hostname}:8080"
}

output "jenkins_role_arn" {
  description = "Jenkins 파드의 IAM Role ARN (IRSA)."
  value       = aws_iam_role.jenkins.arn
}

output "github_webhook_secret_ssm_name" {
  description = "GitHub webhook secret이 저장된 SSM Parameter Store 이름."
  value       = aws_ssm_parameter.github_webhook_secret.name
}

output "jenkins_namespace" {
  description = "Jenkins가 배포된 Kubernetes 네임스페이스."
  value       = var.namespace
}

output "port_forward_command" {
  description = "배스천에서 Jenkins UI에 접근하기 위한 kubectl port-forward 명령어."
  value       = "kubectl port-forward svc/jenkins 8080:8080 -n ${var.namespace}"
}
