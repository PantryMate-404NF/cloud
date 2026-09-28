#!/usr/bin/env bash

source "$(dirname "$0")/../lib/common.sh"

need k6 kubectl jq

log "LOAD TEST"
log "context=$(context)"
log "results=$OUT"

if kubectl get scaledobject -n "$NAMESPACE" -o json |
jq -e '
  .items[]
  | select(
      .metadata.annotations["autoscaling.keda.sh/paused"] == "true"
      or
      .metadata.annotations["autoscaling.keda.sh/paused-replicas"] != null
    )
' >/dev/null; then

  echo "ERROR: KEDA paused."
  exit 1
fi

if kubectl get deploy -n "$NAMESPACE" -o json |
jq -e '
  .items[]
  | select(.metadata.name | startswith("pantry-mate-"))
  | select(
      (.status.readyReplicas // 0)
      <
      (.spec.replicas // 1)
    )
' >/dev/null; then

  echo "ERROR: Some Pantry-Mate deployments are unready."
  exit 1
fi

args=()

for s in \
  FRONTEND \
  GATEWAY \
  USER \
  PRODUCT \
  ORDER_PAYMENT \
  PANTRY_RECIPE \
  NOTIFICATION
do

  key="${s}_URL"

  if [[ -n "${!key:-}" ]]; then
    echo "TARGET $s=${!key}"
    args+=(-e "$key=${!key}")
  fi

done

if [[ "${#args[@]}" -eq 0 ]]; then
  echo "ERROR: Set service URLs in config.local.env"
  exit 1
fi

MAX_VUS="${MAX_VUS:-20}"
[[ "$MAX_VUS" =~ ^[0-9]+$ ]] && ((MAX_VUS >= 1 && MAX_VUS <= 100)) || {
  echo "ERROR: MAX_VUS must be 1..100" >&2
  exit 2
}

# Windows의 k6.exe는 /c/... 형태 경로를 못 읽으므로 C:/... 로 바꿔 넘긴다
winpath() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi
}

log "K6 START max_vus_per_service=$MAX_VUS"

k6 run \
  "${args[@]}" \
  -e MAX_VUS="$MAX_VUS" \
  -e RESULT_DIR="$(winpath "$OUT")" \
  "$(winpath "$ROOT/load/all-services.js")" \
  2>&1 | tee "$OUT/k6.log"

RC=${PIPESTATUS[0]}

log "K6 END rc=$RC"

exit "$RC"
