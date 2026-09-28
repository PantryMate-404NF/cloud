#!/usr/bin/env bash
source "$(dirname "$0")/../lib/common.sh"
START="${START:?Set START to fault injection ISO8601 timestamp}"
END="${END:?Set END to verified service recovery ISO8601 timestamp}"
need python3
python3 - "$START" "$END" <<'PY' | tee -a "$OUT/rto.txt"
import datetime,sys
s=datetime.datetime.fromisoformat(sys.argv[1].replace('Z','+00:00'))
e=datetime.datetime.fromisoformat(sys.argv[2].replace('Z','+00:00'))
if s.tzinfo is None or e.tzinfo is None: raise SystemExit('Use timezone-aware timestamps')
d=(e-s).total_seconds()
if d<0: raise SystemExit('END must follow START')
print(f'Fault start: {s.isoformat()}\nVerified recovery: {e.isoformat()}\nRTO: {d:.1f}s')
PY
