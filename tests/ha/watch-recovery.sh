#!/usr/bin/env bash
source "$(dirname "$0")/../lib/common.sh"
need kubectl
DEPLOYMENT="${DEPLOYMENT:?Set DEPLOYMENT}"
INTERVAL="${INTERVAL:-2}"
TIMEOUT="${TIMEOUT:-600}"
[[ "$INTERVAL" =~ ^[0-9]+$ && "$TIMEOUT" =~ ^[0-9]+$ ]] || exit 2
start=$(date +%s); log "Recovery watcher started target=$DEPLOYMENT"
while (( $(date +%s)-start < TIMEOUT )); do
  desired=$(kubectl get deploy "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)
  ready=$(kubectl get deploy "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  ready="${ready:-0}"
  printf '%s,%s,%s\n' "$(now)" "$desired" "$ready" | tee -a "$OUT/recovery-$DEPLOYMENT.csv"
  if [[ "$desired" =~ ^[0-9]+$ ]] && ((desired>0 && ready>=desired)); then
    log "All replicas ready; elapsed=$(($(date +%s)-start))s"; exit 0
  fi
  sleep "$INTERVAL"
done
log "TIMEOUT waiting for ready replicas"; exit 1
