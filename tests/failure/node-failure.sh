#!/usr/bin/env bash
source "$(dirname "$0")/../lib/common.sh"
need kubectl
NODE="${NODE:?Set NODE}"
kubectl get node "$NODE" -o wide || die "node $NODE not found (context=$(context))"

# tailscale(DB 경로 전체), manage(Jenkins/ArgoCD), gpu(AI 서버) 노드를 drain하면
# 테스트가 아니라 실제 서비스 장애가 되므로 role=worker 노드만 허용
ROLE="$(kubectl get node "$NODE" -o jsonpath='{.metadata.labels.role}')" || die "failed to read node labels"
[[ "$ROLE" == "worker" ]] ||
  die "node $NODE has role='${ROLE:-<none>}'; only role=worker nodes may be drained by this test"

log "Node cordon/drain target=$NODE role=$ROLE"
approve "cordon/drain $NODE"
kubectl cordon "$NODE" || die "cordon failed"
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=5m ||
  die "drain failed; node stays cordoned. Restore: kubectl uncordon $NODE"
log "Drain completed; NOT an EC2 power-off test. Restore: kubectl uncordon $NODE"
