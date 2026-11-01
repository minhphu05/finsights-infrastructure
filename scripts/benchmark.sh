#!/usr/bin/env bash

# Run a bounded HTTP smoke benchmark from the operator workstation with k6.
set -Eeuo pipefail

if ! command -v k6 >/dev/null 2>&1; then
  printf 'k6 is required. Install it from https://grafana.com/docs/k6/latest/set-up/install-k6/\n' >&2
  exit 2
fi

BASE_URL="${FINSIGHTS_BASE_URL:-}"
if [[ -z "${BASE_URL}" ]]; then
  printf 'Set FINSIGHTS_BASE_URL, for example https://finsights.example.com.\n' >&2
  exit 2
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
RESULT_DIR="${REPO_ROOT}/benchmark-results"
mkdir -p "${RESULT_DIR}"

VUS="${FINSIGHTS_BENCHMARK_VUS:-5}"
DURATION="${FINSIGHTS_BENCHMARK_DURATION:-60s}"
HEALTH_PATH="${FINSIGHTS_HEALTH_PATH:-/healthz}"

case "${VUS}" in
  ''|*[!0-9]*) printf 'FINSIGHTS_BENCHMARK_VUS must be a positive integer.\n' >&2; exit 2 ;;
esac
if (( VUS < 1 || VUS > 20 )); then
  printf 'The benchmark is capped at 20 virtual users; requested VUS=%s.\n' "${VUS}" >&2
  exit 2
fi

if [[ ! "${DURATION}" =~ ^([1-9][0-9]*)(s|m)$ ]]; then
  printf 'FINSIGHTS_BENCHMARK_DURATION must be a number followed by s or m, for example 60s.\n' >&2
  exit 2
fi
DURATION_VALUE="${BASH_REMATCH[1]}"
DURATION_UNIT="${BASH_REMATCH[2]}"
if [[ "${DURATION_UNIT}" == "m" ]] && (( DURATION_VALUE > 5 )); then
  printf 'The benchmark duration is capped at 5 minutes.\n' >&2
  exit 2
fi
if [[ "${DURATION_UNIT}" == "s" ]] && (( DURATION_VALUE > 300 )); then
  printf 'The benchmark duration is capped at 300 seconds.\n' >&2
  exit 2
fi

export FINSIGHTS_BASE_URL="${BASE_URL}" FINSIGHTS_HEALTH_PATH="${HEALTH_PATH}"
export FINSIGHTS_BENCHMARK_VUS="${VUS}" FINSIGHTS_BENCHMARK_DURATION="${DURATION}"

k6 run \
  --summary-export "${RESULT_DIR}/summary-$(date -u +%Y%m%dT%H%M%SZ).json" \
  "${SCRIPT_DIR}/k6/finsights-smoke.js"
