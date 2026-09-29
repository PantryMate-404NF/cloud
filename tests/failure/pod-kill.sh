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
WANT="$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')"
START_TS="$(now)"
START_S="$(date +%s)"
kubectl delete pod "$POD" -n "$NAMESPACE" --wait=false || die "pod delete failed"
log "Injected pod deletion"

# 복구 = 지운 파드가 아닌 Ready 파드 수가 삭제 전 레플리카 수로 돌아온 시점
TIMEOUT="${TIMEOUT:-300}"
log "Waiting for $WANT ready pods (excluding $POD, timeout ${TIMEOUT}s)"
while :; do
  READY="$(kubectl get pods -n "$NAMESPACE" -o json | jq --arg d "$DEPLOYMENT" --arg p "$POD" '
    [.items[] | select(.metadata.name | startswith($d+"-")) | select(.metadata.name != $p)
     | select(.metadata.deletionTimestamp == null)
     | select(any(.status.conditions[]?; .type=="Ready" and .status=="True"))] | length')"
  ELAPSED=$(( $(date +%s) - START_S ))
  printf '\r  %3ss  ready=%s/%s' "$ELAPSED" "$READY" "$WANT"
  (( READY >= WANT )) && break
  (( ELAPSED >= TIMEOUT )) && { echo; die "not recovered within ${TIMEOUT}s"; }
  sleep 2
done
echo
END_TS="$(now)"

{
  echo "deployment=$DEPLOYMENT killed_pod=$POD replicas=$WANT"
  echo "start=$START_TS"
  echo "end=$END_TS"
  echo "recovery_seconds=$ELAPSED"
} | tee "$OUT/pod-kill.txt"
log "RECOVERED in ${ELAPSED}s -> $OUT/pod-kill.txt"
