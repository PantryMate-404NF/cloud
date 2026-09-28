#!/usr/bin/env bash
source "$(dirname "$0")/../lib/common.sh"
need kubectl
CLUSTER="${CNPG_CLUSTER:?Set CNPG_CLUSTER}"
NS="${DB_NAMESPACE:-database}"
capture "cnpg-cluster.yaml" kubectl get cluster "$CLUSTER" -n "$NS" -o yaml
capture "cnpg-pods.txt" kubectl get pods -n "$NS" -o wide
capture "cnpg-backups.txt" kubectl get backups -n "$NS" -o wide
log "CNPG snapshot captured; determine RPO from a verified transaction marker, not pod status."
