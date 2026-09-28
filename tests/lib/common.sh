#!/usr/bin/env bash

set -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# config.env = 기본값
[[ -f "$ROOT/config.env" ]] && source "$ROOT/config.env"

# config.local.env = 실제 환경값/URL
[[ -f "$ROOT/config.local.env" ]] && source "$ROOT/config.local.env"

NAMESPACE="${NAMESPACE:-app}"
KEDA_NAMESPACE="${KEDA_NAMESPACE:-keda}"
NODEPOOL="${NODEPOOL:-general}"

# 실행 스크립트에서 TEST_ID를 넘기면 전부 같은 결과 폴더 사용
TEST_ID="${TEST_ID:-$(date +%Y%m%d-%H%M%S)}"
OUT="${OUT:-$ROOT/results/$TEST_ID}"

mkdir -p "$OUT"

now() {
  date -Is
}

log() {
  echo "[$(now)] $*"
}

context() {
  kubectl config current-context 2>/dev/null || echo unknown
}

need() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || {
      echo "ERROR: required command not found: $cmd" >&2
      exit 1
    }
  done
}

capture() {
  local file="$1"
  shift

  {
    echo "===== $(now) ====="
    "$@"
  } > "$OUT/$file" 2>&1 || true
}

approve() {
  local action="$*"

  echo
  echo "============================================================"
  echo " WARNING: DESTRUCTIVE TEST"
  echo " ACTION: $action"
  echo "============================================================"

  if [[ "${AUTO_APPROVE:-false}" == "true" ]]; then
    echo "AUTO_APPROVE=true -> proceeding"
    return 0
  fi

  read -r -p "Type YES to continue: " answer

  [[ "$answer" == "YES" ]] || {
    echo "Cancelled."
    exit 1
  }
}