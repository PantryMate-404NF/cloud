#!/usr/bin/env bash

source "$(dirname "$0")/../lib/common.sh"
need kubectl

FILE="$OUT/db-errors.log"

log "DB error watcher started"

while :; do

  for svc in notification order-payment pantry-recipe product user; do

    PODS=$(
      kubectl get pods -n "$NAMESPACE" \
        -l "app=pantry-mate-$svc" \
        -o jsonpath='{.items[*].metadata.name}' \
        2>/dev/null
    )

    for POD in $PODS; do

      kubectl logs -n "$NAMESPACE" "$POD" \
        --since=15s \
        --timestamps \
        2>&1 |
      grep -Ei \
        'remaining connection slots|too many clients|connection attempt failed|unable to obtain connection|PSQLException|HikariPool' |
      sed "s/^/[$svc][$POD] /" \
      >> "$FILE" || true

    done

  done

  sleep 10
done
