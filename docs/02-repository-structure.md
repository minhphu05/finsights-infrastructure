# Cấu trúc repo `finsights-infrastructure`

## Trách nhiệm

Repo này quản lý hạ tầng 2 VPS và cấu hình nền của máy chủ: mạng WireGuard mesh, firewall/SSH, OS hardening, Docker Engine, K3s Kubernetes runtime, CI/CD và tài liệu vận hành.

Repo này **không** trực tiếp triển khai API/frontend hay application workload. Tất cả microservices, Ingress/Cloudflare Tunnel, PostgreSQL container/StatefulSet sẽ được triển khai bằng Helm charts từ repo `finsights-platform-deployment`.

## Cây thư mục hiện tại

```text
finsights-infrastructure/
├── .github/
│   └── workflows/infra-deploy.yml
├── .gitignore
├── ansible.cfg
├── README.md
├── ansible/
│   ├── ansible.cfg
│   ├── requirements.yml
│   ├── inventory/
│   │   ├── console.example.yml
│   │   └── production.yml
│   ├── playbooks/site.yml
│   └── roles/
│       ├── docker_engine/{defaults,handlers,tasks}/main.yml
│       ├── host_firewall/{defaults,tasks}/main.yml
│       ├── k3s/{defaults,handlers,tasks}/main.yml
│       │   └── templates/config.yaml.j2
│       ├── os_hardening/{defaults,handlers,tasks}/main.yml
│       │   └── templates/{journald-finsights.conf.j2,sshd-finsights.conf.j2}
│       ├── storage_mount/{defaults,tasks}/main.yml
│       └── wireguard/{defaults,handlers,tasks}/main.yml
│           └── templates/wg0.conf.j2

├── scripts/
│   ├── render-ansible-inventory.sh
│   ├── vm-healthcheck.sh
│   ├── benchmark.sh
│   └── k6/finsights-smoke.js
└── docs/
    ├── 01-infrastructure-worklist.md
    ├── 02-repository-structure.md
    ├── architecture-decisions/03-ADR-001-mvp-host-topology.md
    ├── 04-finsights-vm-resource-plan.md
    ├── 05-vm-specification.md
    ├── 07-os-hardening.md
    ├── 08-disaster-recovery.md
    └── runbooks/
        ├── 10-deploy-infrastructure.md
        ├── 11-storage-volume.md
        ├── 12-ssh-access.md
        └── 13-k3s-access.md
```

## Quy ước để tránh cấu hình trùng lặp

- **Ansible & CI/CD là nguồn chuẩn duy nhất để cấu hình hệ thống VPS.**
- Ansible là nguồn chuẩn cho packages, SSH, UFW, mount, Docker Engine cho database containers, và K3s/containerd cho Kubernetes workloads.
- `finsights-platform-deployment` sở hữu Helm charts, manifests, image tags, rollout và cấu hình container của ứng dụng/database/MinIO. Infra không lưu password hoặc service manifest. PostgreSQL/MinIO container dùng data volume tại `/srv/finsights-data`; K3s workloads dùng containerd tích hợp.
- `scripts/vm-healthcheck.sh` đọc trạng thái và phát cảnh báo; `scripts/benchmark.sh` chạy benchmark có giới hạn và ghi kết quả. Script không tự sửa infrastructure ngoài quy trình Ansible.
- Tài liệu runbook hướng dẫn thao tác người vận hành; không chép secret vào docs.

## Ánh xạ với hệ sinh thái Finsights

| Repo | Nội dung thuộc repo |
|---|---|
| `finsights-frontend` | Web app frontend (host trên Vercel) |
| `finsights-backend` | REST API, business logic, authentication, worker jobs |
| `finsights-infrastructure` | Setup VPS, mạng WireGuard mesh, OS hardening, K3s runtime, CI/CD |
| `finsights-core-db` | Database schema, migrations, constraints và seed |
| `finsights-platform-deployment` | Helm charts triển khai ứng dụng và các dịch vụ nền tảng lên K3s |
| `finsights-ai` | AI orchestration, RAG, Agents và LLM pipelines |
