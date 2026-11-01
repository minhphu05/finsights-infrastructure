# ADR-001: Roomify MVP single-host topology

- **Status:** Accepted from Sheet `01 - Infrastructure Plan`, Reviews INF-001/INF-002
- **Date:** 2026-10-11
- **Owners:** Roomify project owner; backup operator to be assigned

## Context

Roomify targets an MVP with roughly ten concurrent users and a small OCI tenancy budget. The reviewed plan records one Ampere A1 VM with 2 OCPU, 12 GB RAM, and a 200 GB total storage budget. A two-node control-plane/worker cluster would consume more compute, while one control-plane node would still leave the cluster without control-plane high availability.

The spreadsheet also records a VM with the target shape. Before provisioning, the operator must verify whether that VM already exists and whether Terraform should adopt it instead of creating another one.

## Decision

Provision one Ubuntu Server 24.04 LTS ARM64 VM with:

- `VM.Standard.A1.Flex`, 2 OCPU and 12 GB RAM.
- 50 GB boot volume and one 150 GB Balanced block volume.
- K3s single-node server with embedded containerd for the Go API, ingress/TLS, and asset worker.
- Docker Engine for PostgreSQL and MinIO containers outside K3s; Redis is optional.
- Persistent data mount at `/srv/roomify-data`.
- Reserved public IPv4 address. OCI NSG allows SSH only from the operator's IPv4 `/32`; public TCP 80/443 are opt-in. No public ingress for Kubernetes API, PostgreSQL, MinIO, Redis, NodePort, or kubelet.
- PostgreSQL/MinIO/optional Redis containers use Docker host networking, bind only to the stable private VNIC IP, and accept application traffic from the K3s pod network. MinIO's administrative console binds to loopback. This avoids Docker bridge port-publishing rules for private services.
- All images and binaries must support `linux/arm64`.

The infrastructure repo provisions OCI resources and host runtimes only. `roomify-platform-deployment` owns all app and service manifests/Compose files and secrets; `roomify-core-db` owns database schema and migrations.

## Consequences

- One VM is a shared failure domain. Reboot, host failure, exhausted memory, or a full data volume can interrupt the entire site.
- PostgreSQL/MinIO data is not protected by Kubernetes rescheduling; their persistence and backups must be handled explicitly by the deployment/backup workflow.
- A1 capacity and Always Free quotas are tenancy-wide. The target 2/12 shape plus 200 GB total volumes may consume the full eligible allocation.
- ARM64 compatibility is a release requirement. Verify application, database, MinIO, worker, and migration images before rollout.
- Host networking removes Docker network isolation for those containers; bind addresses, process ports, UFW rules, and OCI NSG must stay aligned. Compose must not add `ports:` to host-networked services.
- OCI NSG is the public network boundary. UFW is configured to preserve SSH, web, K3s API-private, pod, and service CIDR traffic.

## Review triggers

Revisit this decision if ten-user benchmark results show persistent CPU/memory pressure, if a second host becomes available, if the database or object store needs an independent failure domain, or if uptime requirements change. Scale by moving stateful services or the application to separate hosts only after recalculating Always Free eligibility and cost.
