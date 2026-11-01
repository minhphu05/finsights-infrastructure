# Roomify Ubuntu OS hardening baseline

This document describes the Ansible baseline applied to the Ubuntu 24.04 ARM64 VM. It complements OCI identity controls and NSG rules; it does not replace them.

## Access and SSH

- Use a named operator account provided by the OCI Ubuntu image (`ubuntu`) and its public-key authentication.
- Set `PermitRootLogin no`, `PasswordAuthentication no`, and `KbdInteractiveAuthentication no` through the Ansible SSH drop-in.
- Keep TCP forwarding enabled because Kubernetes API administration may use an SSH tunnel.
- Restrict TCP 22 at both OCI NSG and UFW to the operator's current IPv4 `/32`.
- Keep the private key outside the repository and rotate/revoke keys when an operator loses access.
- Confirm the new SSH session works before ending the existing session after any SSH/firewall change.

## Host firewall and K3s

The OCI security list has no ingress rules. The NSG is the perimeter and permits only operator SSH plus optional 80/443. UFW denies incoming by default and permits SSH, optional web ports, K3s API only from the VCN range, and K3s pod/service CIDRs required by the single-node CNI. It allows outbound traffic for updates and image pulls.

K3s recommends disabling UFW unless the required API and pod/service network rules are configured. The role explicitly keeps UFW and writes those rules before enabling it. Do not open UDP 8472, kubelet, NodePort, PostgreSQL, Redis, or MinIO through the OCI NSG. Review current [K3s networking requirements](https://docs.k3s.io/installation/requirements) after changing cluster CIDRs or topology.

Docker-published bridge ports can be diverted before UFW input rules. To avoid that path, the runtime contract uses Docker host networking for PostgreSQL/MinIO/optional Redis, bound only to the stable private VNIC address; MinIO console binds to loopback. Do not declare Compose `ports:` for these host-networked services. K3s pods use the private VM address; UFW admits K3s pod/service CIDRs and OCI NSG still blocks public stateful-service ports. Review [Docker's packet filtering guidance](https://docs.docker.com/engine/network/packet-filtering-firewalls/) and [host network behavior](https://docs.docker.com/engine/network/drivers/host/) if changing this design.

## Updates, time, and logs

- Install Ubuntu security update support, Chrony, and common inspection tools.
- Keep unattended security updates enabled. Schedule planned reboots and verify K3s, Docker, mount, and app health afterward.
- Use `Asia/Ho_Chi_Minh` timezone for operator-facing host logs; application timestamps should remain UTC.
- Bound journald persistence to 512 MB and volatile logs to 256 MB. Docker logs use the `local` driver with 10 MB / 3-file rotation.
- Review `/var` and `/srv/roomify-data` usage regularly. Do not enable unbounded debug logs during production traffic.

## Storage and service boundaries

The role mounts the 150 GB block volume by UUID at `/srv/roomify-data`. It does not create or permission application data directories. The deployment repo owns database/object service manifests and container IDs. Keep durable data off the boot volume and back it up outside the VM.

## Operational review

After applying Ansible, check `sudo ufw status verbose`, `sudo sshd -t`, `systemctl is-active docker k3s`, `lsblk -f`, and `findmnt /srv/roomify-data`. Confirm the public IP cannot reach TCP 6443, 5432, 6379, 9000, or 9001. Re-run these checks after rule, OS, or K3s updates.
