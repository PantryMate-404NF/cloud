#!/usr/bin/env bash

source "$(dirname "$0")/../lib/common.sh"

need kubectl jq

log "LOAD TEST"
log "context=$(context)"
log "results=$OUT"

# ------------------------------------------------------------
# 1. KEDA가 pause 상태인지 확인
# ------------------------------------------------------------
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

# ------------------------------------------------------------
# 2. Pantry-Mate Deployment가 모두 Ready인지 확인
# ------------------------------------------------------------
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

# ------------------------------------------------------------
# 3. 설정된 URL 수집
# ------------------------------------------------------------
ENV_ARGS=()

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
    ENV_ARGS+=("--env=${key}=${!key}")
  fi
done

if [[ "${#ENV_ARGS[@]}" -eq 0 ]]; then
  echo "ERROR: Set service URLs in config.local.env"
  exit 1
fi

# ------------------------------------------------------------
# 4. k6 script를 ConfigMap으로 EKS에 전달
# ------------------------------------------------------------
K6_CONFIGMAP="k6-load-script"
K6_POD="k6-load-test"

kubectl delete configmap "$K6_CONFIGMAP" \
  -n "$NAMESPACE" \
  --ignore-not-found >/dev/null

kubectl create configmap "$K6_CONFIGMAP" \
  -n "$NAMESPACE" \
  --from-file=all-services.js="$ROOT/load/all-services.js"

# 이전 테스트 Pod 제거
kubectl delete pod "$K6_POD" \
  -n "$NAMESPACE" \
  --ignore-not-found \
  --wait=true >/dev/null

log "K6 START"

# ------------------------------------------------------------
# 5. EKS 내부에서 k6 실행
# ------------------------------------------------------------
kubectl run "$K6_POD" \
  -n "$NAMESPACE" \
  --image=grafana/k6:latest \
  --restart=Never \
  "${ENV_ARGS[@]}" \
  --overrides="
{
  \"spec\": {
    \"containers\": [
      {
        \"name\": \"$K6_POD\",
        \"image\": \"grafana/k6:latest\",
        \"args\": [
          \"run\",
          \"/scripts/all-services.js\"
        ],
        \"volumeMounts\": [
          {
            \"name\": \"k6-script\",
            \"mountPath\": \"/scripts\"
          }
        ]
      }
    ],
    \"volumes\": [
      {
        \"name\": \"k6-script\",
        \"configMap\": {
          \"name\": \"$K6_CONFIGMAP\"
        }
      }
    ]
  }
}"

# Pod가 실제 생성될 때까지 대기
kubectl wait \
  -n "$NAMESPACE" \
  --for=jsonpath='{.status.phase}'=Running \
  "pod/$K6_POD" \
  --timeout=120s || true

# ------------------------------------------------------------
# 6. k6 결과 실시간 출력 + 로컬 저장
# ------------------------------------------------------------
kubectl logs \
  -n "$NAMESPACE" \
  -f "$K6_POD" \
  | tee "$OUT/k6.log"

# ------------------------------------------------------------
# 7. 종료 코드 확인
# ------------------------------------------------------------
RC=$(kubectl get pod "$K6_POD" \
  -n "$NAMESPACE" \
  -o jsonpath='{.status.containerStatuses[0].state.terminated.exitCode}' \
  2>/dev/null)

RC="${RC:-1}"

log "K6 END rc=$RC"

exit "$RC"