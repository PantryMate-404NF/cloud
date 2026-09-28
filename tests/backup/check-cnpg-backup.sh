#!/usr/bin/env bash
source "$(dirname "$0")/../lib/common.sh"
need kubectl
NS="${DB_NAMESPACE:-database}"
capture "cnpg-backup-list.txt" kubectl get backups -n "$NS" -o wide
capture "cnpg-backup-list.json" kubectl get backups -n "$NS" -o json
log "Backup presence is not proof of successful restore; verify data separately."
