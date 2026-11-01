# Finsights Infrastructure

This repository provisions and manages the infrastructure, inter-node networking, host operating systems, and Kubernetes runtime for **Finsights**.

The infrastructure runs on **2 dedicated VPS nodes** connected through an encrypted **Tailscale VPN mesh**, delivering **8 vCPU, 16 GB RAM, and 120 GB SSD Storage**.

The repository stops at the host runtime boundary. Application workloads, Ingress routing, and container configurations are deployed as Helm charts in a separate platform deployment repository. Database schemas and migrations are managed in `finsights-core-db`.

---

## 1. 2-Node VPS Cluster Architecture

```text
 ┌────────────────────────────────────────────────────────────────────────┐
 │                           INTERNET (Public)                            │
 └───────────────────┬────────────────────────────────┬───────────────────┘
                     │ SSH Port 26567                 │ SSH Port 26566
                     ▼                                ▼
 ┌─────────────────────────────────────────┐      ┌─────────────────────────────────────────┐
 │   Node 1 (Control Plane)                │      │   Node 2 (Worker + DB)                  │
 │   Public IP: 103.249.117.232            │      │   Public IP: 103.249.117.201            │
 │   SSH Port: 26567 (internal 8686)       │      │   SSH Port: 26566 (internal 8686)       │
 │   4 vCPU, 8 GB RAM, 60 GB SSD           │      │   4 vCPU, 8 GB RAM, 60 GB SSD           │
 │  ┌───────────────────────────────────┐  │      │  ┌───────────────────────────────────┐  │
 │  │ Tailscale Mesh IP (tailscale0)    │◀─┼──────┼─▶│ Tailscale Mesh IP (tailscale0)    │  │
 │  └─────────────────┬─────────────────┘  │      │  └─────────────────┬─────────────────┘  │
 │                    │                    │      │                    │                    │
 │  • K3s Control Plane (Server)           │      │  • K3s Worker (Agent)                   │
 │  • Flannel CNI via tailscale0           │      │  • Flannel CNI via tailscale0           │
 │  • Ingress Controller (Ports 80/443)    │      │  • PostgreSQL / Database Container      │
 │  • Data directory: /srv/finsights-data  │      │  • Data directory: /srv/finsights-data  │
 └─────────────────────────────────────────┘      └─────────────────────────────────────────┘
```

### Resource Allocation Matrix

| Node | Host IP | SSH Port | Specs | Mesh Interface | Role & Workload Distribution |
|---|---|---|---|---|---|
| **Node 1** | `103.249.117.232` | `26567` | 4 vCPU, 8 GB RAM, 60 GB SSD | `tailscale0` | **K3s Control Plane (Server)**<br>• Ingress Controller (HTTP/HTTPS)<br>• Data directory (`/srv/finsights-data`) |
| **Node 2** | `103.249.117.201` | `26566` | 4 vCPU, 8 GB RAM, 60 GB SSD | `tailscale0` | **K3s Worker (Agent) + Dedicated PostgreSQL**<br>• Database storage (`/srv/finsights-data`)<br>• Application background services |
| **Total** | **2 VPS Nodes** | - | **8 vCPU, 16 GB RAM, 120 GB SSD** | `100.64.0.0/10` | **Encrypted high-performance 2-node cluster** |

---

## 2. Repository Structure

| Path | Responsibility |
|---|---|
| `.github/workflows/infra-deploy.yml` | GitHub Actions CI/CD pipeline for automated provisioning |
| `ansible/ansible.cfg` | Ansible configuration with optimized SSH connection parameters |
| `ansible/inventory/production.yml` | Production inventory for the 2 VPS nodes |
| `ansible/playbooks/site.yml` | Master playbook executing baseline OS hardening, Tailscale, Docker, and K3s |
| `ansible/roles/os_hardening` | Security hardening, journald limits, SSH hardening (key-only root login) |
| `ansible/roles/host_firewall` | UFW rules allowing SSH (8686/22/custom), Tailscale (41641 UDP + tailscale0), K3s (6443) |
| `ansible/roles/tailscale` | Automated Tailscale mesh setup, peer authentication, and route acceptance |
| `ansible/roles/docker_engine` | Docker Engine + Compose plugin (dynamic x86_64 / arm64 support) |
| `ansible/roles/storage_mount` | Sets up `/srv/finsights-data` storage directory with strict permissions |
| `ansible/roles/k3s` | Installs K3s Server on Node 1 and K3s Agent on Node 2 over Tailscale mesh |
| `scripts/render-ansible-inventory.sh` | Builds `production.yml` inventory from environment variables |
| `scripts/vm-healthcheck.sh` | Inspects node health, CPU/RAM, Tailscale `tailscale0`, K3s, and storage |

---

## 3. Deployment Workflow

### Automated CI/CD (GitHub Actions)
Deployments are automated through GitHub Actions:
1. Store the SSH private key in GitHub repository Secrets as `SSH_PRIVATE_KEY`.
2. Store the Tailscale Auth Key in GitHub repository Secrets as `TAILSCALE_AUTHKEY` (generate at [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys) with Reusable option).
3. Push changes to `main` branch or trigger manually via **Actions > Deploy Finsights Infrastructure > Run workflow**.

### Manual / Local Execution
To deploy or update nodes directly:

```bash
# 1. Ensure private key and Tailscale auth key are available
export ANSIBLE_SSH_KEY_FILE="~/.ssh/finsights_vps"
export TAILSCALE_AUTHKEY="tskey-auth-..."

# 2. Run Ansible playbook
cd ansible
ansible-playbook -i inventory/production.yml playbooks/site.yml
```

### Healthcheck Verification
Check cluster and node readiness on the Control Plane:

```bash
ssh -i ~/.ssh/finsights_vps -p 26567 root@103.249.117.232 "k3s kubectl get nodes -o wide"
```
