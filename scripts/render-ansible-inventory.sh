#!/usr/bin/env bash

# Generate Ansible production inventory for Finsights VPS infrastructure.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

NODE1_IP="${NODE1_IP:-103.249.117.232}"
NODE1_PORT="${NODE1_PORT:-26567}"
NODE2_IP="${NODE2_IP:-103.249.117.201}"
NODE2_PORT="${NODE2_PORT:-26566}"
SSH_KEY="${FINSIGHTS_SSH_PRIVATE_KEY:-~/.ssh/finsights_vps}"
INVENTORY_PATH="${REPO_ROOT}/ansible/inventory/production.yml"

mkdir -p "$(dirname -- "${INVENTORY_PATH}")"

cat <<EOF > "${INVENTORY_PATH}"
---
all:
  vars:
    ansible_ssh_private_key_file: "${SSH_KEY}"
    ansible_ssh_common_args: "-o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    admin_ssh_cidr: "0.0.0.0/0"
    tailscale_authkey: "{{ lookup('env', 'TAILSCALE_AUTHKEY') | default('', true) }}"
  children:
    finsights_control_plane:
      hosts:
        finsights-prod-node-01:
          ansible_host: "${NODE1_IP}"
          ansible_port: ${NODE1_PORT}
          ansible_user: root
          k3s_role: server
          has_data_volume: false

    finsights_workers:
      hosts:
        finsights-prod-node-02:
          ansible_host: "${NODE2_IP}"
          ansible_port: ${NODE2_PORT}
          ansible_user: root
          k3s_role: agent
          has_data_volume: false

    finsights_hosts:
      children:
        finsights_control_plane:
        finsights_workers:
EOF

chmod 600 "${INVENTORY_PATH}"
echo "Wrote ${INVENTORY_PATH} successfully."
