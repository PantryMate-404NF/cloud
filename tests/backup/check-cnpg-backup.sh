#!/usr/bin/env bash
source "$(dirname "$0")/../lib/common.sh"
need kubectl
NS="${DB_NAMESPACE:-database}"
# CNPG는 온프레미스 클러스터에 있으므로 onprem_kubectl 사용 (EKS context로는 조회되지 않음)
onprem_kubectl get namespace "$NS" >/dev/null ||
  die "namespace $NS not found in context $ONPREM_KUBE_CONTEXT"
capture "cnpg-backup-list.txt" onprem_kubectl get backups -n "$NS" -o wide
capture "cnpg-backup-list.json" onprem_kubectl get backups -n "$NS" -o json
log "Backup presence is not proof of successful restore; verify data separately."
