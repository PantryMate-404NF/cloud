#!/usr/bin/env bash
source "$(dirname "$0")/../lib/common.sh"
need kubectl
capture "events-$(date +%H%M%S).txt" kubectl get events -A --sort-by=.lastTimestamp
capture "nodeclaims-$(date +%H%M%S).yaml" kubectl get nodeclaim -o yaml
capture "keda-errors-$(date +%H%M%S).txt" kubectl logs -n "${KEDA_NAMESPACE:-keda}" deploy/keda-operator --since=30m --tail=500
