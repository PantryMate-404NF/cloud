#!/usr/bin/env bash

source "$(dirname "$0")/../lib/common.sh"
need kubectl

INTERVAL="${INTERVAL:-10}"

[[ "$INTERVAL" =~ ^[0-9]+$ ]] && ((INTERVAL >= 5)) || {
  echo "INTERVAL must be >= 5"
  exit 2
}

log "Monitoring every ${INTERVAL}s"
log "output=$OUT/timeline.log"

while :; do
  {
    echo
    echo "============================================================"
    echo "===== $(now) ====="
    echo "============================================================"

    echo
    echo "===== HPA ====="
    kubectl get hpa -n "$NAMESPACE"

    echo
    echo "===== DEPLOYMENTS ====="
    kubectl get deploy -n "$NAMESPACE"

    echo
    echo "===== PODS ====="
    kubectl get pods -n "$NAMESPACE" -o wide

    echo
    echo "===== NODES ====="
    kubectl get nodes \
      -L topology.kubernetes.io/zone,karpenter.sh/nodepool,karpenter.sh/capacity-type,node.kubernetes.io/instance-type

    echo
    echo "===== NODECLAIMS ====="
    kubectl get nodeclaim -o wide

    echo
    echo "===== POD RESOURCE ====="
    kubectl top pods -n "$NAMESPACE" 2>&1 || true

    echo
    echo "===== NODE RESOURCE ====="
    kubectl top nodes 2>&1 || true

  } >> "$OUT/timeline.log" 2>&1

  sleep "$INTERVAL"
done
