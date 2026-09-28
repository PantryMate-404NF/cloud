#!/usr/bin/env bash
source "$(dirname "$0")/../lib/common.sh"
need kubectl
PHASE="${1:-before}"
[[ "$PHASE" == before || "$PHASE" == after ]] || { echo "Usage: $0 before|after" >&2; exit 2; }
log "$PHASE context=$(context)"
capture "$PHASE-nodes.txt" kubectl get nodes -o wide
capture "$PHASE-pods.txt" kubectl get pods -A -o wide
capture "$PHASE-deployments.txt" kubectl get deployments -n "$NAMESPACE" -o wide
capture "$PHASE-hpa.txt" kubectl get hpa -n "$NAMESPACE" -o wide
capture "$PHASE-scaledobjects.json" kubectl get scaledobject -n "$NAMESPACE" -o json
capture "$PHASE-nodeclaims.json" kubectl get nodeclaim -o json
capture "$PHASE-nodepool.yaml" kubectl get nodepool -o yaml
capture "$PHASE-events.txt" kubectl get events -A --sort-by=.lastTimestamp
capture "$PHASE-pod-top.txt" kubectl top pods -n "$NAMESPACE"
capture "$PHASE-node-top.txt" kubectl top nodes
