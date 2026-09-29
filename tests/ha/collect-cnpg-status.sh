#!/usr/bin/env bash
source "$(dirname "$0")/../lib/common.sh"
need kubectl
CLUSTER="${CNPG_CLUSTER:?Set CNPG_CLUSTER}"
NS="${DB_NAMESPACE:-database}"
# CNPG는 온프레미스 클러스터에 있으므로 onprem_kubectl 사용 (EKS context로는 조회되지 않음)
onprem_kubectl get cluster "$CLUSTER" -n "$NS" >/dev/null ||
  die "CNPG cluster $NS/$CLUSTER not found in context $ONPREM_KUBE_CONTEXT"
capture "cnpg-cluster.yaml" onprem_kubectl get cluster "$CLUSTER" -n "$NS" -o yaml
capture "cnpg-pods.txt" onprem_kubectl get pods -n "$NS" -o wide
capture "cnpg-backups.txt" onprem_kubectl get backups -n "$NS" -o wide
log "CNPG snapshot captured; determine RPO from a verified transaction marker, not pod status."
