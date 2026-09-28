#!/usr/bin/env bash
source "$(dirname "$0")/../lib/common.sh"
need kubectl jq
DEPLOYMENT="${DEPLOYMENT:?Set DEPLOYMENT}"
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" >/dev/null ||
  die "deployment $NAMESPACE/$DEPLOYMENT not found (context=$(context))"
POD="$(kubectl get pods -n "$NAMESPACE" -o json | jq -r --arg d "$DEPLOYMENT" '.items[] | select(.metadata.name | startswith($d+"-")) | select(any(.status.containerStatuses[]?;.ready==true)) | .metadata.name' | head -1)"
[[ -n "$POD" ]] || die "No ready pod for $DEPLOYMENT"
log "Pod deletion target=$NAMESPACE/$POD"
approve "delete pod $POD"
kubectl delete pod "$POD" -n "$NAMESPACE" --wait=false || die "pod delete failed"
log "Injected pod deletion"
