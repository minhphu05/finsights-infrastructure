# ADR-001: Finsights 2-Node VPS Cluster Topology

- **Status:** Accepted
- **Date:** 2026-11-01
- **Owners:** Finsights Infrastructure & DevOps Team

## Context

Finsights requires a cost-effective, high-performance infrastructure baseline to host application services, background ingestion workers, and a dedicated PostgreSQL database. Previous attempts to use Oracle Cloud Always Free ARM instances encountered severe cloud capacity exhaustion (out of capacity in ap-tokyo-1 and ap-singapore-1).

To ensure deterministic provisioning and reliable performance, Finsights transitioned to **two dedicated x86_64 VPS instances** (4 vCPU, 8 GB RAM, 60 GB SSD each).

## Decision

1. **Topology:**
   - **Node 1 (`103.249.117.232:26567`):** Acts as K3s Control Plane (Server), Ingress entrypoint, and runs Cloudflare Tunnel daemon (`cloudflared`).
   - **Node 2 (`103.249.117.201:26566`):** Acts as K3s Worker (Agent), dedicated to PostgreSQL database persistence and background workers.
2. **Inter-Node Networking:**
   - Encrypted WireGuard VPN mesh (`wg0`) established between Node 1 (`10.8.0.1/24`) and Node 2 (`10.8.0.2/24`). All inter-node Kubernetes and pod traffic traverses `wg0`.
3. **Public Exposure & Ingress:**
   - Frontend is hosted on Vercel Edge Network.
   - Backend APIs are published via **Cloudflare Tunnel**, avoiding direct exposure of VPS IP addresses or dependency on inbound port 80/443 NAT forwarding.
4. **Separation of Concerns:**
   - `finsights-infrastructure` owns OS hardening, SSH access, UFW, WireGuard, Docker Engine, and K3s cluster bootstrap.
   - `finsights-platform-deployment` owns all application Helm charts, microservices, Ingress routes, database StatefulSets, and PVCs.

## Consequences

- Low inter-node latency (< 0.5 ms measured in the same datacenter).
- Secure, zero-port-forwarding public access via Cloudflare Tunnel.
- Workloads and databases are deployed declaratively via Helm charts with explicit `nodeSelector` pinning.
