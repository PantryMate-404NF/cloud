#!/usr/bin/env bash
# 배포 롤백 관찰: 잘못된 배포가 클러스터에 들어온 시점, 롤백이 반영된 시점, 정상 복구 시점을 자동 기록
# 사용: DEPLOYMENT=pantry-mate-product bash failure/rollback-watch.sh
#   실행하면 지금의 이미지를 "정상 이미지"로 기억한 뒤, gitops 에 잘못된 배포와 revert 를 푸시하면 된다
source "$(dirname "$0")/../lib/common.sh"
need kubectl jq

DEPLOYMENT="${DEPLOYMENT:?Set DEPLOYMENT}"
INTERVAL="${INTERVAL:-2}"
TIMEOUT="${TIMEOUT:-1800}"

GOOD_IMAGE="$(kubectl get deploy "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].image}')" ||
  die "deployment $NAMESPACE/$DEPLOYMENT not found (context=$(context))"
WANT="$(kubectl get deploy "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')"

CSV="$OUT/rollback-$DEPLOYMENT.csv"
echo "time,template_image,ready,updated,unavailable,pods" > "$CSV"

log "Rollback watcher target=$NAMESPACE/$DEPLOYMENT replicas=$WANT"
log "good image = $GOOD_IMAGE"
log "이제 gitops 에 잘못된 배포를 푸시하세요 (중단: Ctrl+C)"

BAD_AT="" BAD_IMAGE="" REVERT_AT="" CLEAN_AT="" MIN_READY="$WANT"
start_s="$(date +%s)"

while :; do
  (( $(date +%s) - start_s >= TIMEOUT )) && die "timeout ${TIMEOUT}s"

  dep="$(kubectl get deploy "$DEPLOYMENT" -n "$NAMESPACE" -o json 2>/dev/null)" || { sleep "$INTERVAL"; continue; }
  image="$(jq -r '.spec.template.spec.containers[0].image' <<<"$dep")"
  ready="$(jq -r '.status.readyReplicas // 0' <<<"$dep")"
  updated="$(jq -r '.status.updatedReplicas // 0' <<<"$dep")"
  unavail="$(jq -r '.status.unavailableReplicas // 0' <<<"$dep")"
  # 파드별 "이미지태그:상태" (예: b2e8df0b:Ready  rollback-test:ErrImagePull)
  pods="$(kubectl get pods -n "$NAMESPACE" -o json | jq -r --arg d "$DEPLOYMENT-" '
    [.items[] | select(.metadata.name | startswith($d)) | select(.metadata.deletionTimestamp == null)
     | (.spec.containers[0].image | split(":") | last) + ":" +
       ( if any(.status.conditions[]?; .type == "Ready" and .status == "True") then "Ready"
         else (.status.containerStatuses[0].state.waiting.reason // .status.phase) end )] | join(" ")')"
  ts="$(now)"
  echo "$ts,${image##*:},$ready,$updated,$unavail,$pods" >> "$CSV"
  printf '\r%s  template=%-28s ready=%s/%s  pods=[%s]\033[K' "$(date +%H:%M:%S)" "${image##*:}" "$ready" "$WANT" "$pods"

  (( ready < MIN_READY )) && MIN_READY="$ready"

  if [[ -z "$BAD_AT" && "$image" != "$GOOD_IMAGE" ]]; then
    BAD_AT="$ts"; BAD_S="$(date +%s)"; BAD_IMAGE="$image"
    echo; log "BAD DEPLOY detected: $image"
  elif [[ -n "$BAD_AT" && -z "$REVERT_AT" && "$image" == "$GOOD_IMAGE" ]]; then
    REVERT_AT="$ts"; REVERT_S="$(date +%s)"
    echo; log "ROLLBACK applied: template back to good image"
  elif [[ -n "$REVERT_AT" && -z "$CLEAN_AT" ]]; then
    # 복구 = 모든 파드가 정상 이미지로 Ready, 잘못된 이미지 파드 없음
    bad_left="$(grep -o "${BAD_IMAGE##*:}:" <<<"$pods" | wc -l)"
    if (( ready >= WANT && bad_left == 0 )); then
      CLEAN_AT="$ts"; CLEAN_S="$(date +%s)"
      echo; log "RECOVERED: all pods on good image and ready"
      break
    fi
  fi

  sleep "$INTERVAL"
done

{
  echo "deployment=$DEPLOYMENT replicas=$WANT"
  echo "good_image=$GOOD_IMAGE"
  echo "bad_image=$BAD_IMAGE"
  echo "bad_deploy_seen=$BAD_AT"
  echo "rollback_seen=$REVERT_AT"
  echo "recovered=$CLEAN_AT"
  echo "bad_state_seconds=$(( REVERT_S - BAD_S ))      # 잘못된 배포가 클러스터에 있던 시간"
  echo "rollback_to_recovered_seconds=$(( CLEAN_S - REVERT_S ))"
  echo "min_ready_during_test=$MIN_READY/$WANT     # $WANT 이면 잘못된 배포 동안에도 정상 파드가 줄지 않았다는 뜻"
} | tee "$OUT/rollback.txt"
log "result -> $OUT/rollback.txt, $CSV"
