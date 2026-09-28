#!/usr/bin/env bash
source "$(dirname "$0")/../lib/common.sh"
need kubectl
NODE="${NODE:?Set NODE}"
kubectl get node "$NODE" -o wide
log "Node cordon/drain target=$NODE"
approve "cordon/drain $NODE"
kubectl cordon "$NODE"
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=5m
log "Drain completed; NOT an EC2 power-off test. Restore: kubectl uncordon $NODE"
