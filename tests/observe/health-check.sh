#!/usr/bin/env bash

source "$(dirname "$0")/../lib/common.sh"
need kubectl jq

FAILED=0

log "Pre-flight health check"
log "context=$(context)"

echo
echo "===== DEPLOYMENTS ====="
kubectl get deploy -n "$NAMESPACE"

echo
echo "===== KEDA ====="
kubectl get scaledobject -n "$NAMESPACE"

echo
echo "===== HPA ====="
kubectl get hpa -n "$NAMESPACE"

echo
echo "===== NODEPOOL / NODECLAIM ====="
kubectl get nodepool,nodeclaim

echo
echo "===== KEDA PAUSED CHECK ====="

PAUSED=$(
  kubectl get scaledobject -n "$NAMESPACE" -o json |
  jq -r '
    .items[]
    | select(
        .metadata.annotations["autoscaling.keda.sh/paused"] == "true"
        or
        .metadata.annotations["autoscaling.keda.sh/paused-replicas"] != null
      )
    | .metadata.name
  '
)

if [[ -n "$PAUSED" ]]; then
  echo "FAIL: paused ScaledObject:"
  echo "$PAUSED"
  FAILED=1
else
  echo "OK"
fi

echo
echo "===== DEPLOYMENT READY CHECK ====="

UNREADY=$(
  kubectl get deploy -n "$NAMESPACE" -o json |
  jq -r '
    .items[]
    | select(.metadata.name | startswith("pantry-mate-"))
    | select(
        (.status.readyReplicas // 0)
        <
        (.spec.replicas // 1)
      )
    | "\(.metadata.name) ready=\(.status.readyReplicas // 0)/\(.spec.replicas // 1)"
  '
)

if [[ -n "$UNREADY" ]]; then
  echo "FAIL:"
  echo "$UNREADY"
  FAILED=1
else
  echo "OK"
fi

echo
echo "===== CRASHLOOP CHECK ====="

CRASH=$(
  kubectl get pods -n "$NAMESPACE" -o json |
  jq -r '
    .items[]
    | select(
        any(
          .status.containerStatuses[]?;
          .state.waiting.reason == "CrashLoopBackOff"
        )
      )
    | .metadata.name
  '
)

if [[ -n "$CRASH" ]]; then
  echo "FAIL:"
  echo "$CRASH"
  FAILED=1
else
  echo "OK"
fi

echo
echo "===== METRICS API ====="

if kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes >/dev/null 2>&1; then
  echo "OK"
else
  echo "FAIL"
  FAILED=1
fi

echo
echo "===== HPA UNKNOWN METRIC CHECK ====="

HPA_OUT=$(kubectl get hpa -n "$NAMESPACE")

echo "$HPA_OUT"

if echo "$HPA_OUT" | grep -q '<unknown>'; then
  echo
  echo "FAIL: HPA contains <unknown> metrics"
  # KEDA 트리거가 VM1 Prometheus(onprem-gateway:9090, Tailscale 경유)를 조회하므로 VM 연결 끊김이 흔한 원인
  echo "HINT: check VM1 Prometheus reachability via Tailscale (onprem-gateway.monitoring.svc:9090)"
  echo "      kubectl logs -n monitoring deploy/tailscale-proxy -c tailscale --since=5m | grep -E 'open-conn-track|new contact'"
  FAILED=1
else
  echo
  echo "OK"
fi

echo
echo "===== RESULT ====="

if (( FAILED != 0 )); then
  echo "PRE-CHECK FAILED — LOAD TEST BLOCKED"
  exit 1
fi

echo "PRE-CHECK PASSED"
