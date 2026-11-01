# Cấu trúc repo `roomify-infrastructure`

## Trách nhiệm

Repo này quản lý hạ tầng OCI và cấu hình nền của máy chủ: network, compute, volumes, firewall/SSH, OS hardening, Docker/Kubernetes runtime, health checks, benchmark và tài liệu khôi phục.

Repo này **không** triển khai Roomify API/frontend hay workload containers. Go API, ingress/TLS, asset worker, PostgreSQL, MinIO và Redis tùy chọn đều được triển khai từ `roomify-platform-deployment`; PostgreSQL/MinIO/Redis chạy bằng Docker Engine ngoài K3s trên cùng VM. Schema, migration và seed thuộc `roomify-core-db`.

## Cây thư mục hiện tại

```text
roomify-infrastructure/
├── .gitignore
├── README.md
├── draft.txt
├── terraform/
│   ├── modules/
│   │   ├── network/{main.tf,variables.tf,outputs.tf,versions.tf}
│   │   ├── compute/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   ├── versions.tf
│   │   │   └── cloud-init/bootstrap.yaml
│   │   └── storage/{main.tf,variables.tf,outputs.tf,versions.tf}
│   └── environments/
│       ├── dev/
│       │   ├── .terraform.lock.hcl
│       │   ├── README.md
│       │   ├── main.tf
│       │   ├── outputs.tf
│       │   ├── provider.tf
│       │   ├── terraform.tfvars.example
│       │   ├── variables.tf
│       │   └── versions.tf
│       └── prod/
│           ├── .terraform.lock.hcl
│           ├── main.tf
│           ├── outputs.tf
│           ├── provider.tf
│           ├── terraform.tfvars.example
│           ├── variables.tf
│           └── versions.tf
├── ansible/
│   ├── ansible.cfg
│   ├── requirements.yml
│   ├── inventory/console.example.yml
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
    ├── 04-roomify-vm-resource-plan.md
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
- `finsights-platform-deployment` sở hữu Compose/Helm/manifests, image tags, rollout và cấu hình container của ứng dụng/database/MinIO. Infra không lưu password hoặc service manifest. PostgreSQL/MinIO container dùng data volume tại `/srv/finsights-data`; K3s workloads dùng containerd tích hợp.
- `scripts/vm-healthcheck.sh` đọc trạng thái và phát cảnh báo; `scripts/benchmark.sh` chạy benchmark có giới hạn và ghi kết quả. Script không tự sửa infrastructure ngoài quy trình Ansible.
- Tài liệu runbook hướng dẫn thao tác người vận hành; không chép secret vào docs.

## Ánh xạ với các repo Roomify

| Repo | Nội dung thuộc repo |
|---|---|
| `roomify-frontend` | Web app, editor 2D/3D và render trên browser |
| `roomify-backend` | REST API, business logic, authentication, project/catalog |
| `roomify-infrastructure` | OCI resources, network, OS, hardening và runtime |
| `roomify-core-db` | Database schema, migrations, constraints và seed |
| `roomify-platform-deployment` | Triển khai ứng dụng và các dịch vụ nền tảng lên môi trường |
| `roomify-ai` | AI orchestration, Vision, RAG, Agents và recommendation |
