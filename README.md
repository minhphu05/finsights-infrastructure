# Finsights Infrastructure

This repository provisions and manages the cloud infrastructure, inter-node networking, host operating systems, and Kubernetes runtime for **Finsights**.

The infrastructure spans across multiple Oracle Cloud Free Tier tenancies connected through an encrypted **WireGuard VPN mesh**, delivering **4 OCPU, 24 GB RAM, and 400 GB NVMe Storage** at zero cloud cost.

The repository stops at the host runtime boundary. [`finsights-platform-deployment`](../finsights-platform-deployment/) owns application workloads, Ingress routing, and container configurations. `finsights-core-db` owns database schemas and migrations.

---

## 1. Multi-Node Cross-Tenancy Architecture

```text
 ┌────────────────────────────────────────────────────────────────────────┐
 │                           INTERNET (Public)                            │
 └───────────────────────────────────┬────────────────────────────────────┘
                                     │ (Public Web 80/443 & SSH /32 only)
                                     ▼
 ┌─────────────────────────────────────────┐           ┌─────────────────────────────────────────┐
 │   Node 1 (Account 1 - Tokyo - NRT)      │           │   Node 2 (Account 2 - Singapore - SIN)  │
 │   Public IP: Reserved                   │           │   Public IP: Reserved                   │
 │   VCN 1: 10.20.0.0/16 (Private: .10)    │           │   VCN 2: 10.30.0.0/16 (Private: .10)    │
 │  ┌───────────────────────────────────┐  │ WireGuard │  ┌───────────────────────────────────┐  │
 │  │ WireGuard VPN IP: 10.8.0.1/24     │◀─┼───────────┼─▶│ WireGuard VPN IP: 10.8.0.2/24     │  │
 │  └─────────────────┬─────────────────┘  │ (UDP:51820│  └─────────────────┬─────────────────┘  │
 │                    │                    │ encrypted)│                    │                    │
 │  • K3s Control Plane (Server)           │           │  • K3s Worker 2 (Agent)                 │
 │  • K3s Worker 1 (Flannel via wg0)       │           │  • Flannel CNI via wg0                  │
 │  • Ingress Controller (Ports 80/443)    │           │  • Dedicated PostgreSQL (Port 5432)     │
 │  • Data Volume 1: 150 GB (MinIO/Assets) │           │  • Data Volume 2: 150 GB (PG Data/WAL)  │
 └─────────────────────────────────────────┘           └─────────────────────────────────────────┘
```

### Resource Allocation Matrix

| Node | Tenancy / Region | RAM | OCPU | Storage | Role & Workload Distribution |
|---|---|---|---|---|---|
| **Node 1** | Account 1 (`ap-tokyo-1`) | 12 GB | 2 | 50 GB Boot + 150 GB Block | **K3s Control Plane + Worker 1**<br>• Ingress Controller (HTTP/HTTPS)<br>• Stateless web/API workloads<br>• MinIO / Object Storage mount |
| **Node 2** | Account 2 (`ap-singapore-1`) | 12 GB | 2 | 50 GB Boot + 150 GB Block | **K3s Worker 2 + Dedicated DB**<br>• Dedicated PostgreSQL (binds to `10.8.0.2`)<br>• Background workers / batch jobs<br>• Dedicated 150 GB DB volume |
| **Total** | 2 Accounts | **24 GB** | **4** | **400 GB** | **High-efficiency, decoupled data & compute** |

---

## 2. Scale-Out Mechanism for Future Nodes

The infrastructure is intentionally designed to scale horizontally across any number of Oracle Cloud or external accounts:

1. **Network**: Every node participates in a WireGuard mesh interface (`wg0`). Node 1 is `10.8.0.1`, Node 2 is `10.8.0.2`. Adding a Node 3 simply assigns `10.8.0.3` and registers peers. All Kubernetes and database traffic flows encrypted through `wg0`.
2. **K3s Clustering**: Node 1 acts as the K3s server. Any new node automatically joins the cluster as a `k3s-agent` using the internal WireGuard endpoint `https://10.8.0.1:6443` and join token.
3. **Workload Scheduling**: Nodes are tagged with roles (`role=control-plane-worker`, `role=storage-worker`). Workloads target appropriate nodes via `nodeSelector` / `tolerations`.
4. **Persistent Storage**: Persistent volumes are bound to specific host mount points (`/srv/finsights-data`), keeping PostgreSQL data decoupled from web application lifecycle.

---

## 3. Repository Map

| Path | Responsibility |
|---|---|
| `.oci/` | OCI authentication profiles (`account1`, `account2`) and API keys (Git-ignored) |
| `terraform/modules/` | Reusable OCI modules: `network` (with WireGuard UDP 51820 rule), `compute`, `storage` |
| `terraform/environments/prod` | Production composition managing Node 1 and Node 2 across accounts |
| `ansible/roles/wireguard` | Automated WireGuard key generation and cross-node mesh configuration |
| `ansible/roles/k3s` | Installs K3s Server on Node 1 and K3s Agent on Node 2 over WireGuard |
| `ansible/roles/storage_mount` | Formats and mounts the 150 GB volume to `/srv/finsights-data` |
| `ansible/roles/host_firewall` | Hardened UFW configuration (SSH /32, WireGuard UDP 51820, internal `wg0`) |
| `ansible/roles/docker_engine` | Docker Engine + Compose plugin for standalone database containers |
| `scripts/render-ansible-inventory.sh` | Dynamically builds multi-node inventory from Terraform state |
| `scripts/vm-healthcheck.sh` | Inspects node health, CPU/RAM, WireGuard `wg0`, K3s, and storage |

---

## 4. Deployment Workflow

### Step 1: Provision Cloud Resources via Terraform
```bash
cd terraform/environments/prod

# 1. Initialize modules and providers
terraform init

# 2. Plan and review changes (26 resources to add across 2 tenancies)
terraform plan -out=finsights-prod.tfplan

# 3. Apply the reviewed plan
terraform apply finsights-prod.tfplan
```

### Step 2: Configure Nodes via Ansible
```bash
cd ../../..

# 1. Export local private SSH key path (corresponding to ssh_public_key in tfvars)
export FINSIGHTS_SSH_PRIVATE_KEY="$HOME/.ssh/id_rsa"

# 2. Generate multi-node inventory from Terraform outputs
./scripts/render-ansible-inventory.sh prod

# 3. Execute Ansible playbook (formats empty 150 GB volumes on first run)
ansible-playbook ansible/playbooks/site.yml -e initialize_data_volume=true
```
*(On subsequent runs, omit `-e initialize_data_volume=true` to preserve existing data).*

---

## 5. Verification & Health Check

After deployment, verify the cluster:

```bash
# 1. SSH into Node 1 (Tokyo)
ssh -i ~/.ssh/id_rsa ubuntu@<node1_public_ip>

# Check WireGuard mesh connectivity
sudo wg show
ping -c 3 10.8.0.2

# Check K3s cluster nodes
sudo k3s kubectl get nodes -o wide

# Run local health check
./scripts/vm-healthcheck.sh
```

Both `finsights-prod-node-01` and `finsights-prod-node-02` will appear as **Ready** in `kubectl get nodes`!
