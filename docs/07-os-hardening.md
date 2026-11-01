# Finsights Ubuntu OS Hardening Baseline

This document describes the Ansible baseline applied to the Ubuntu 24.04 LTS (x86_64) VPS nodes for Finsights.

## Access and SSH

- Key-based authentication only: `PermitRootLogin prohibit-password`, `PasswordAuthentication no`, and `KbdInteractiveAuthentication no` configured via `/etc/ssh/sshd_config.d/60-finsights.conf`.
- Ports preserved: SSH daemon listens on custom internal port `8686` and standard port `22` (forwarded from external NAT ports `26567` for Node 1 and `26566` for Node 2).
- Keep TCP and tunnel forwarding enabled (`AllowTcpForwarding yes`, `PermitTunnel yes`) for management and tunnel connectivity.
- Private SSH keys are kept outside the repository and injected via CI/CD secrets (`SSH_PRIVATE_KEY`) or local operator `~/.ssh/finsights_vps`.

## Host Firewall (UFW) and K3s

- UFW policy: Deny incoming by default, allow outgoing.
- Rules configured before UFW is enabled:
  - SSH management ports: `8686`, `22`, and custom node ports (`26567`, `26566`).
  - WireGuard mesh: UDP port `51820` and all traffic on internal interface `wg0`.
  - K3s API: TCP port `6443` restricted to WireGuard mesh network (`10.8.0.0/24`).
  - K3s internal CNI: Pod CIDR (`10.42.0.0/16`) and Service CIDR (`10.43.0.0/16`).
  - Web ingress: Optional TCP `80` and `443`.

## Updates, Time, and Logs

- Automatic security updates enabled via `unattended-upgrades`.
- NTP time synchronization enabled via `chrony`.
- System timezone set to `Asia/Ho_Chi_Minh`.
- Journald limits: Bounded retention to 512 MB persistent and 256 MB volatile logs.
- Docker daemon log rotation: Bounded with max-size `10m` and max-file `3`.

## Storage and Service Boundaries

- Persistent local data directory is initialized at `/srv/finsights-data` with mode `0750`.
- Application workloads, PVCs, database storage, and container definitions are managed via Helm charts in the deployment repository.
