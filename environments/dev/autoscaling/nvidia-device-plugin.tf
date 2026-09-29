# GPU 노드의 user-data 가 containerd 에 "nvidia" 런타임을 추가하지만 기본 런타임으로는 두지 않으므로,
# GPU 를 쓰는 파드는 runtimeClassName: nvidia 로 이 런타임을 지정해야 한다.
resource "kubectl_manifest" "nvidia_runtime_class" {
  yaml_body = <<-YAML
    apiVersion: node.k8s.io/v1
    kind: RuntimeClass
    metadata:
      name: nvidia
    handler: nvidia
  YAML
}

resource "helm_release" "nvidia_device_plugin" {
  name      = "nvidia-device-plugin"
  namespace = "kube-system"

  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"
  version    = "0.20.1"

  values = [yamlencode({
    runtimeClassName = "nvidia"

    # NFD 를 설치하지 않으므로 기본 affinity(NFD 라벨 기반) 대신 GPU 노드그룹 라벨로 배치
    affinity = {
      nodeAffinity = {
        requiredDuringSchedulingIgnoredDuringExecution = {
          nodeSelectorTerms = [{
            matchExpressions = [{
              key      = "role"
              operator = "In"
              values   = ["gpu"]
            }]
          }]
        }
      }
    }
  })]

  wait    = true
  atomic  = true
  timeout = 600

  depends_on = [kubectl_manifest.nvidia_runtime_class]
}
