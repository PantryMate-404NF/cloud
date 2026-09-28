#!/usr/bin/env bash
source "$(dirname "$0")/../lib/common.sh"
need kubectl
POD="${POD:?Set POD}"
DURATION="${DURATION:-60}"
WORKERS="${WORKERS:-1}"
# 앱 이미지에는 stress 도구가 없으므로 같은 Pod에 임시(ephemeral) 디버그 컨테이너를 붙여 부하를 건다
STRESS_IMAGE="${STRESS_IMAGE:-alexeiled/stress-ng:latest}"
[[ "$DURATION" =~ ^[0-9]+$ ]] && ((DURATION>=1 && DURATION<=300)) || { echo "DURATION must be 1..300" >&2; exit 2; }
[[ "$WORKERS" =~ ^[0-9]+$ ]] && ((WORKERS>=1 && WORKERS<=4)) || { echo "WORKERS must be 1..4" >&2; exit 2; }
kubectl get pod "$POD" -n "$NAMESPACE" >/dev/null || die "pod $NAMESPACE/$POD not found (context=$(context))"
TARGET="${CONTAINER:-$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].name}')}"
[[ -n "$TARGET" ]] || die "failed to resolve target container"

log "CPU stress $NAMESPACE/$POD container=$TARGET workers=$WORKERS duration=${DURATION}s image=$STRESS_IMAGE"
approve "CPU stress $POD ($WORKERS worker(s), ${DURATION}s)"
# 임시 컨테이너는 Pod가 재생성될 때까지 기록이 남지만(종료 상태) 서비스에는 영향이 없다
kubectl debug -n "$NAMESPACE" "$POD" --image="$STRESS_IMAGE" --target="$TARGET" --profile=general \
  -- stress-ng --cpu "$WORKERS" --timeout "${DURATION}s" --metrics-brief ||
  die "failed to attach ephemeral stress container"
log "Stress container attached; running for ${DURATION}s"
sleep "$DURATION"
log "CPU stress window finished"
