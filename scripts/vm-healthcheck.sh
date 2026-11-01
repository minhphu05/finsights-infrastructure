#!/usr/bin/env bash

# Read-only local checks for the Finsights host. Run this script on the VM itself.
set -Eeuo pipefail

DATA_MOUNT="${FINSIGHTS_DATA_MOUNT:-${ROOMIFY_DATA_MOUNT:-/srv/finsights-data}}"
FAILED=0

check_service() {
  local service="$1"
  if systemctl is-active --quiet "${service}"; then
    printf 'PASS  service %-22s active\n' "${service}"
  else
    printf 'FAIL  service %-22s inactive\n' "${service}"
    FAILED=1
  fi
}

check_service docker
if systemctl list-unit-files | grep -q "k3s.service"; then
  check_service k3s
elif systemctl list-unit-files | grep -q "k3s-agent.service"; then
  check_service k3s-agent
fi

# Check WireGuard if configured
if ip link show wg0 >/dev/null 2>&1; then
  printf 'PASS  interface %-20s up\n' "wg0 (WireGuard)"
else
  printf 'WARN  interface %-20s not found\n' "wg0 (WireGuard)"
fi

CPU_COUNT="$(nproc)"
LOAD_AVERAGE="$(awk '{print $1, $2, $3}' /proc/loadavg)"
printf 'INFO  cpu/load               %s CPUs; load averages %s\n' "${CPU_COUNT}" "${LOAD_AVERAGE}"

MEMORY_AVAILABLE_PERCENT="$(awk '
  /^MemTotal:/ { total = $2 }
  /^MemAvailable:/ { available = $2 }
  END {
    if (total > 0) {
      printf "%d", (available * 100 / total)
    } else {
      print "0"
    }
  }
' /proc/meminfo)"
if (( MEMORY_AVAILABLE_PERCENT < 10 )); then
  printf 'WARN  memory headroom         only %s%% available\n' "${MEMORY_AVAILABLE_PERCENT}"
else
  printf 'PASS  memory headroom         %s%% available\n' "${MEMORY_AVAILABLE_PERCENT}"
fi

check_disk_usage() {
  local path="$1"
  local usage

  usage="$(df -P "${path}" | awk 'NR == 2 { gsub(/%/, "", $5); print $5 }')"
  if [[ -z "${usage}" ]]; then
    printf 'FAIL  disk usage              could not read %s\n' "${path}"
    FAILED=1
  elif (( usage >= 85 )); then
    printf 'FAIL  disk usage              %s is %s%% full\n' "${path}" "${usage}"
    FAILED=1
  elif (( usage >= 70 )); then
    printf 'WARN  disk usage              %s is %s%% full\n' "${path}" "${usage}"
  else
    printf 'PASS  disk usage              %s is %s%% full\n' "${path}" "${usage}"
  fi
}

if [[ -d "${DATA_MOUNT}" ]]; then
  printf 'PASS  data directory          %s\n' "${DATA_MOUNT}"
  check_disk_usage "${DATA_MOUNT}"
else
  printf 'FAIL  data directory          %s does not exist\n' "${DATA_MOUNT}"
  FAILED=1
fi
check_disk_usage /

if [[ "${EUID}" -eq 0 ]]; then
  K3S_COMMAND=(k3s kubectl)
else
  K3S_COMMAND=(sudo -n k3s kubectl)
fi

if command -v k3s >/dev/null 2>&1 && "${K3S_COMMAND[@]}" wait --for=condition=Ready nodes --all --timeout=5s >/dev/null 2>&1; then
  printf 'PASS  Kubernetes cluster      Ready\n'
fi

printf '\nFilesystem capacity:\n'
df -hP / "${DATA_MOUNT}" 2>/dev/null || true

printf '\nMemory summary:\n'
free -h

exit "${FAILED}"
