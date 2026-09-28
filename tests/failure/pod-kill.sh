#!/usr/bin/env bash
source "$(dirname "$0")/../lib/common.sh"
need kubectl jq
DEPLOYMENT="${DEPLOYMENT:?Set DEPLOYMENT}"
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" >/dev/null
POD="$(kubectl get pods -n "$NAMESPACE" -o json | jq -r --arg d "$DEPLOYMENT" '.items[] | select(.metadata.name | startswith($d+"-")) | select(any(.status.containerStatuses[]?;.ready==true)) | .metadata.name' | head -1)"
[[ -n "$POD" ]] || { echo "No ready pod" >&2; exit 1; }
log "Pod deletion target=$NAMESPACE/$POD"
approve "delete pod $POD"
kubectl delete pod "$POD" -n "$NAMESPACE" --wait=false
log "Injected pod deletion"
