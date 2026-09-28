#!/usr/bin/env bash

set -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 우선순위: 명령줄 환경변수(CNPG_CLUSTER=x ./script) > config.local.env > config.env
# 그냥 source하면 config.env의 빈 값(CNPG_CLUSTER=)이 명령줄 값을 덮어쓰므로, 이미 설정된 변수는 건너뛴다
_PRESET_VARS=" $(compgen -e | tr '\n' ' ') "
load_config() {
  local file="$1" line key
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)= ]] || continue
    key="${BASH_REMATCH[1]}"
    [[ "$_PRESET_VARS" == *" $key "* ]] && continue
    eval "$line"
  done < "$file"
}

# config.env = 기본값
load_config "$ROOT/config.env"

# config.local.env = 실제 환경값/URL
load_config "$ROOT/config.local.env"

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

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# Windows Git Bash의 python3는 스토어 연결 파일이라 실행되지 않으므로 python으로 대체
python_bin() {
  local cand
  for cand in python3 python; do
    if command -v "$cand" >/dev/null 2>&1 && "$cand" -c 'import sys; sys.exit(sys.version_info < (3, 9))' >/dev/null 2>&1; then
      echo "$cand"
      return 0
    fi
  done
  die "python 3.9+ not found (python3 or python)"
}

# CNPG는 EKS가 아니라 온프레미스(VM1) 쿠버네티스에 있으므로 context를 명시해서 호출
onprem_kubectl() {
  [[ -n "${ONPREM_KUBE_CONTEXT:-}" ]] ||
    die "Set ONPREM_KUBE_CONTEXT in config.local.env (on-prem cluster kubeconfig context; see README 4.1)"
  kubectl --context "$ONPREM_KUBE_CONTEXT" "$@"
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