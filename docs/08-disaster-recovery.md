# Roomify infrastructure backup and disaster recovery

**Target from Review INF-004:** RTO ≤24 hours and RPO ≤24 hours. These are objectives, not guarantees, until the backup destination, schedule, credentials, and restore drill are in place.

## Failure model

Production is one VM. The host is a shared failure domain for K3s, Docker, PostgreSQL, MinIO, and the public IP attachment. A boot-volume snapshot alone cannot restore database/object consistency; a snapshot in the same tenancy is not the only backup copy. Keep application-level backups outside the VM and verify they can be read independently.

## Backup matrix

| Item | What to preserve | Owner / method | Required location |
|---|---|---|---|
| PostgreSQL | Consistent logical or physical backup, WAL strategy if selected, schema/migrations | `roomify-platform-deployment` coordinates with `roomify-core-db` | Encrypted destination outside this VM; restore test within 24 h objective |
| MinIO | Objects and required metadata/configuration | `roomify-platform-deployment`; versioning/replication/export plan | Independent object storage or offline copy; checksum sample objects |
| Kubernetes | K3s server state, cluster token, config, manifests | Platform deployment backup procedure; secrets protected | Encrypted off-VM copy with access limited to operators |
| Host infrastructure | Terraform state, source code, Ansible inventory inputs, image/version pins | `roomify-infrastructure` | Encrypted private backup; Terraform state never in Git |
| OCI resources | VM image choice, reserved public IP, volume IDs, NSG/route definitions | Terraform state and OCI inventory | Repository plus protected state backup |

Do not commit SSH private keys, K3s tokens, kubeconfig, database passwords, MinIO secrets, `.env`, or plaintext backup encryption keys.

## Backup cadence and retention

The initial target is at least one PostgreSQL backup and one incremental/full MinIO data copy each day, with a restore point no older than 24 hours. Before beta, record exact schedules, retention, encryption, storage location, failure notifications, and monthly restore drill owner. Also check current OCI Always Free Block Volume backup allowance; don't assume a particular backup count remains available or that it replaces off-VM application backups.

## Restore sequence

1. Declare an incident, record start time, and choose the latest verified backup within the RPO objective.
2. Recreate OCI network and VM from the production Terraform environment in the confirmed Home Region. If the previous VM is still available, inspect it before replacing anything.
3. Attach the existing data volume only after confirming its OCID and availability domain; do not format it. If it is lost, create a new volume and restore application data from the independent backup.
4. Apply Ansible. For an existing filesystem, leave `initialize_data_volume=false`; confirm mount by UUID at `/srv/roomify-data`.
5. Restore K3s config/secrets according to the protected backup procedure, or build a fresh single-node cluster and reapply manifests from `roomify-platform-deployment`.
6. Restore PostgreSQL and validate migrations/schema, representative rows, constraints, and application connectivity.
7. Restore MinIO objects and verify checksums for representative Roomify assets. Confirm bucket policy and access credentials without publishing the console.
8. Confirm app/worker health, upload/download paths, backups, monitoring, NSG/UFW exposure, and 10-user capacity headroom.
9. Reassign the reserved public IP if required, then update Cloudflare DNS only after HTTPS and health checks pass.
10. Record elapsed time and data-loss point. If either exceeds 24 hours, document the gap and revise the backup plan.

## Restore drill record

Keep a dated record in the team's incident log with: source backup ID/time, target environment, checksum results, restore duration, data validation outcome, DNS decision, and corrective actions. Never run a destructive restore drill against production data.
