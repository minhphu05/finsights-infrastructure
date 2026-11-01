# Finsights production VM specification

**Baseline:** Multi-Node Production VPS Cluster  
**Architecture:** 2 VPS nodes (x86_64, 4 vCPU, 8 GB RAM, 60 GB SSD each)  
**Cluster runtime:** K3s Server (Node 1) + K3s Agent (Node 2) over Tailscale mesh  

## Compute and operating system

| Setting | Node 1 (Control Plane) | Node 2 (Worker + DB) |
|---|---|---|
| Host IP | `103.249.117.232` | `103.249.117.201` |
| SSH Port | `26567` (internal `8686`) | `26566` (internal `8686`) |
| CPU and RAM | 4 vCPU, 8 GB RAM | 4 vCPU, 8 GB RAM |
| Architecture | x86_64 (`amd64`) | x86_64 (`amd64`) |
| Operating System | Ubuntu Server 24.04 LTS | Ubuntu Server 24.04 LTS |
| Disk Storage | 60 GB SSD (`/dev/vda1`) | 60 GB SSD (`/dev/vda1`) |
| Mesh Interface | `tailscale0` | `tailscale0` |
| Cluster Role | K3s Server (Control Plane) | K3s Agent (Worker) |

## Host responsibility map

| Service | Where it runs | Owner |
|---|---|---|
| OS, UFW, SSH, Docker Engine, K3s, Tailscale | Host system | `finsights-infrastructure` |
| Ingress / Web API, application pods | K3s cluster | `finsights-platform-deployment` |
| PostgreSQL database, MinIO object storage | Docker Engine / Persistent storage | `finsights-core-db` / `finsights-platform-deployment` |
| Data directory | `/srv/finsights-data` | Local persistent SSD |

## Network exposure

| Port | Source | Purpose |
|---:|---|---|
| TCP 26567 / 26566 (internal 8686/22) | Management | SSH administration |
| UDP 41641 / `tailscale0` | Inter-node | Tailscale VPN mesh |
| TCP 6443 | `100.64.0.0/10` (Tailscale) | K3s Kubernetes API |
| TCP 80/443 | Public Internet | HTTP/HTTPS Web Ingress |
