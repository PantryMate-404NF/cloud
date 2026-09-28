#!/usr/bin/env bash
source "$(dirname "$0")/../lib/common.sh"
START="${START:?Set START to restore request ISO8601 timestamp}"
END="${END:?Set END to verified DB query ISO8601 timestamp}"
need python3
python3 - "$START" "$END" <<'PY' | tee -a "$OUT/restore-duration.txt"
import datetime,sys
s=datetime.datetime.fromisoformat(sys.argv[1].replace('Z','+00:00'))
e=datetime.datetime.fromisoformat(sys.argv[2].replace('Z','+00:00'))
if s.tzinfo is None or e.tzinfo is None or e<s: raise SystemExit('Invalid timezone-aware timestamps')
print(f'Restore start: {s.isoformat()}\nVerified query: {e.isoformat()}\nRestore duration: {(e-s).total_seconds():.1f}s')
PY
