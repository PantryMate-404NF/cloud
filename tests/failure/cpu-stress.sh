#!/usr/bin/env bash
source "$(dirname "$0")/../lib/common.sh"
need kubectl
POD="${POD:?Set POD}"
DURATION="${DURATION:-60}"
[[ "$DURATION" =~ ^[0-9]+$ ]] && ((DURATION>=1 && DURATION<=300)) || { echo "DURATION must be 1..300" >&2; exit 2; }
kubectl get pod "$POD" -n "$NAMESPACE" >/dev/null
log "CPU stress $NAMESPACE/$POD duration=${DURATION}s"
approve "CPU stress $POD"
kubectl exec -n "$NAMESPACE" "$POD" -- sh -c 'if command -v stress-ng >/dev/null; then exec stress-ng --cpu 1 --timeout "$1"s; elif command -v stress >/dev/null; then exec stress --cpu 1 --timeout "$1"s; else echo "stress tool unavailable" >&2; exit 127; fi' sh "$DURATION"
log "CPU stress completed"
