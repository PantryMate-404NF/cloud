#!/usr/bin/env bash

set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

TEST_ID="$(date +%Y%m%d-%H%M%S)"
export TEST_ID
export OUT="$ROOT/results/$TEST_ID"

mkdir -p "$OUT"

source "$ROOT/lib/common.sh"

WATCH_PID=""
DB_PID=""

cleanup() {

  echo
  log "Stopping background watchers..."

  [[ -z "$WATCH_PID" ]] || kill "$WATCH_PID" 2>/dev/null || true
  [[ -z "$DB_PID" ]] || kill "$DB_PID" 2>/dev/null || true

  wait "$WATCH_PID" 2>/dev/null || true
  wait "$DB_PID" 2>/dev/null || true
}

trap cleanup EXIT INT TERM

echo "============================================================"
echo " PANTRY-MATE AUTOSCALING TEST"
echo "============================================================"
echo
echo "TEST_ID : $TEST_ID"
echo "RESULT  : $OUT"
echo "START   : $(now)"
echo

echo "===== STEP 1/8 : HEALTH CHECK ====="

if ! "$ROOT/observe/health-check.sh" \
  2>&1 | tee "$OUT/precheck.log"; then

  echo
  echo "============================================================"
  echo " PRE-CHECK FAILED"
  echo " LOAD TEST NOT STARTED"
  echo "============================================================"

  exit 1
fi

echo
echo "===== STEP 2/8 : BASELINE BEFORE ====="

"$ROOT/baseline/collect.sh" before

echo
echo "===== STEP 3/8 : INITIAL EVENTS ====="

"$ROOT/observe/collect-events.sh"

echo
echo "===== STEP 4/8 : START WATCHERS ====="

"$ROOT/observe/watch.sh" &
WATCH_PID=$!

"$ROOT/observe/watch-db.sh" &
DB_PID=$!

echo "watch PID=$WATCH_PID"
echo "db    PID=$DB_PID"

sleep 10

echo
echo "===== STEP 5/8 : LOAD TEST ====="

LOAD_START="$(now)"
echo "$LOAD_START" > "$OUT/load-start.txt"

LOAD_ORCHESTRATED=1 "$ROOT/load/run.sh"
LOAD_RC=$?

LOAD_END="$(now)"
echo "$LOAD_END" > "$OUT/load-end.txt"

echo
echo "===== LOAD FINISHED rc=$LOAD_RC ====="

echo
echo "===== STEP 6/8 : SCALE-IN / CONSOLIDATION OBSERVATION ====="
echo "Observing for 10 minutes..."
echo "Karpenter consolidateAfter is expected to require additional time."

for i in {1..20}; do

  echo
  echo "----- POST LOAD $i/20 : $(now) -----"

  kubectl get hpa -n "$NAMESPACE"

  echo

  kubectl get nodeclaim -o wide

  sleep 30
done

echo
echo "===== STEP 7/8 : BASELINE AFTER ====="

"$ROOT/baseline/collect.sh" after

echo
echo "===== STEP 8/8 : FINAL EVENTS ====="

"$ROOT/observe/collect-events.sh"

echo "$(now)" > "$OUT/test-end.txt"

cleanup

trap - EXIT INT TERM

echo
echo "============================================================"
echo " AUTOSCALING TEST COMPLETE"
echo "============================================================"
echo
echo "RESULT DIRECTORY:"
echo "$OUT"
echo
echo "LOAD RC: $LOAD_RC"
echo

echo "===== RESULT FILES ====="
find "$OUT" -maxdepth 1 -type f -printf '%f\n' | sort

exit "$LOAD_RC"
