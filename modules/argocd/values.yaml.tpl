global:
  domain: "argocd.internal"

server:
  # manage 노드에만 스케줄링
  nodeSelector:
    role: "${manage_node_label}"

  # 외부 노출 없음 — Tailscale VPN 또는 kubectl port-forward로만 접근
  service:
    type: ClusterIP

  # UI 접근 시 HTTPS 강제 해제 (port-forward 환경)
  extraArgs:
    - --insecure

repoServer:
  nodeSelector:
    role: "${manage_node_label}"

applicationSet:
  nodeSelector:
    role: "${manage_node_label}"

notifications:
  nodeSelector:
    role: "${manage_node_label}"

redis:
  nodeSelector:
    role: "${manage_node_label}"

dex:
  enabled: false

configs:
  params:
    # 기본 3분 polling → 1분으로 단축
    application.instanceLabelKey: argocd.argoproj.io/app-name
    server.repo.server.timeout.seconds: "300"
