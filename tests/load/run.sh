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
[[ "$MAX_VUS" =~ ^[0-9]+$ ]] && ((MAX_VUS >= 1 && MAX_VUS <= 500)) || {
  echo "ERROR: MAX_VUS must be 1..500" >&2
  exit 2
}

SLEEP="${SLEEP:-1}"
HOLD="${HOLD:-2m}"
PROFILE="${PROFILE:-ramp}"

total_vus=$(( MAX_VUS * ${#args[@]} / 2 ))

if (( total_vus > 200 )) || [[ "$SLEEP" == "0" ]]; then
  echo "WARNING: 고부하 모드 (총 최대 ${total_vus} VU, SLEEP=${SLEEP}s)"
  echo "         Cloudflare 가 429/403 으로 막을 수 있고, 로컬 PC 의 CPU·네트워크가 먼저 한계에 닿을 수 있음"
  echo "         중단: Ctrl+C"
fi

# Windows의 k6.exe는 /c/... 형태 경로를 못 읽으므로 C:/... 로 바꿔 넘긴다
winpath() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi
}

# run-autoscaling-test.sh 에서 부르면 LOAD_ORCHESTRATED=1: 상세 기록(watch.sh)과 부하 후 관찰은 그쪽이 맡는다
LOAD_ORCHESTRATED="${LOAD_ORCHESTRATED:-0}"

if [[ "$LOAD_ORCHESTRATED" == "1" ]]; then
  POST_OBSERVE="${POST_OBSERVE:-0}"
else
  # HPA 축소 대기(2분) + Karpenter consolidateAfter(5분)를 보려면 8분 정도 필요
  POST_OBSERVE="${POST_OBSERVE:-8m}"
fi

[[ "$POST_OBSERVE" =~ ^[0-9]+[sm]?$ ]] || {
  echo "ERROR: POST_OBSERVE must look like 0, 90s, 8m" >&2
  exit 2
}

# 하위 스크립트(watch.sh)가 같은 결과 폴더에 쓰도록 넘긴다
export TEST_ID OUT

# 15초마다 한 줄: 시각, 노드 수, HPA별 레플리카
record_scaling() {
  while :; do
    {
      printf '%s nodes=%s ' "$(date +%H:%M:%S)" \
        "$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')"
      kubectl get hpa -n "$NAMESPACE" --no-headers 2>/dev/null |
        awk '{ n = $1; sub(/^keda-hpa-/, "", n); sub(/^pantry-mate-/, "", n); sub(/-scaler$/, "", n);
               printf "%s=%s ", n, $(NF-1) }'
      echo
    } >> "$OUT/scaling.log"
    sleep 15
  done
}

# scaling.log 에서 항목별 시작값·최대값(처음 도달 시각)·마지막 값을 뽑는다
summarize_scaling() {
  [[ -s "$OUT/scaling.log" ]] || return 0
  awk '
    {
      t = $1
      for (i = 2; i <= NF; i++) {
        split($i, kv, "=")
        k = kv[1]; v = kv[2] + 0
        if (!(k in first)) { first[k] = v; peak[k] = v; peakt[k] = t; order[++n] = k }
        if (v > peak[k]) { peak[k] = v; peakt[k] = t }
        last[k] = v
      }
    }
    END {
      for (j = 1; j <= n; j++) {
        k = order[j]
        mark = (peak[k] > first[k]) ? "  <- scaled out" : ""
        printf "  %-15s start=%-3s peak=%-3s (%s) end=%s%s\n", k, first[k], peak[k], peakt[k], last[k], mark
      }
    }
  ' "$OUT/scaling.log"
}

REC_PID=""
WATCH_PID=""
FINALIZED=0

finalize() {
  [[ "$FINALIZED" == "1" ]] && return
  FINALIZED=1

  [[ -z "$REC_PID" ]] || kill "$REC_PID" 2>/dev/null
  [[ -z "$WATCH_PID" ]] || kill "$WATCH_PID" 2>/dev/null
  wait 2>/dev/null

  log "SAVING RESULTS"

  # 쿠버네티스 이벤트는 약 1시간 뒤 사라지므로 끝나자마자 저장
  capture hpa-events.txt kubectl get events -n "$NAMESPACE" \
    --field-selector reason=SuccessfulRescale --sort-by=.lastTimestamp
  capture karpenter-events.txt kubectl get events -A \
    --field-selector source=karpenter --sort-by=.lastTimestamp
  capture nodeclaims.txt kubectl get nodeclaim -o wide
  capture hpa-final.txt kubectl get hpa -n "$NAMESPACE"

  {
    echo "TEST_ID=$TEST_ID"
    echo "context=$(context)"
    echo "load_start=${LOAD_START:-?} load_end=${LOAD_END:-?}"
    sed -n '/===== LOAD SUMMARY =====/,$p' "$OUT/k6.log" 2>/dev/null
    echo "===== SCALING (15s 간격, 시각은 로컬) ====="
    summarize_scaling
    echo
    echo "files: k6.log k6-summary.json scaling.log hpa-events.txt karpenter-events.txt nodeclaims.txt"
    [[ "$LOAD_ORCHESTRATED" == "1" ]] || echo "       timeline.log (10초 간격 HPA·파드·노드 상세)"
    echo "hpa-events.txt / karpenter-events.txt 시각은 UTC (+9시간 = 한국 시간)"
  } > "$OUT/summary.txt"

  echo
  sed -n '/===== SCALING/,$p' "$OUT/summary.txt"
  echo
  echo "RESULT: $OUT/summary.txt"
}

trap finalize EXIT
trap 'exit 130' INT TERM

record_scaling &
REC_PID=$!

if [[ "$LOAD_ORCHESTRATED" != "1" ]]; then
  "$ROOT/observe/watch.sh" >/dev/null 2>&1 &
  WATCH_PID=$!
fi

log "K6 START profile=$PROFILE max_vus_per_service=$MAX_VUS sleep=${SLEEP}s hold=$HOLD"
LOAD_START="$(now)"

k6 run \
  "${args[@]}" \
  -e MAX_VUS="$MAX_VUS" \
  -e SLEEP="$SLEEP" \
  -e HOLD="$HOLD" \
  -e PROFILE="$PROFILE" \
  -e RESULT_DIR="$(winpath "$OUT")" \
  "$(winpath "$ROOT/load/all-services.js")" \
  2>&1 | tee -i "$OUT/k6.log"   # -i: Ctrl+C 때 k6 가 찍는 최종 요약까지 파일에 남도록 tee 는 신호를 무시

RC=${PIPESTATUS[0]}
LOAD_END="$(now)"

log "K6 END rc=$RC"

if [[ "$POST_OBSERVE" != "0" ]]; then
  log "부하 종료 후 스케일인 관찰 $POST_OBSERVE (건너뛰려면 Ctrl+C, 결과는 그래도 저장됨)"
  sleep "$POST_OBSERVE"
fi

exit "$RC"
