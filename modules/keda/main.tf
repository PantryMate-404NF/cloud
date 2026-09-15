resource "helm_release" "keda" {
  name             = "keda"
  namespace        = var.namespace
  create_namespace = true

  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = var.chart_version

  wait    = true
  atomic  = true
  timeout = 600
}
### KEDA module에서는 Controller 설치 기능만 함.
### ScaledObject(애플리케이션별 scaling policy)와는 분리.