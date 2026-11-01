# Finsights Infrastructure & DevOps Worklist

**Trạng thái:** Triển khai hạ tầng Production 2-Node VPS  
**Cập nhật:** 01-11-2026  
**Kiến trúc:** 2 VPS (4 Core CPU, 8 GB RAM, 60 GB SSD mỗi máy)

## 1. Cơ sở và phạm vi

Phạm vi của `finsights-infrastructure` là thiết lập, hardening OS, firewall, Tailscale VPN mesh, Docker Engine và runtime K3s cho cụm 2 VPS. 

Repo này dừng lại ở ranh giới runtime máy chủ. Tất cả microservices, Backend API, Ingress/Cloudflare Tunnel, PostgreSQL container/StatefulSet, PVC và CronJobs sẽ được quản lý bằng Helm charts trong repo deployment riêng (`finsights-platform-deployment`).

### Cấu hình phần cứng

| Môi trường | Cấu hình máy chủ | Runtime | Ghi chú |
|---|---|---|---|
| **Node 1** | VPS 4 Core / 8 GB RAM / 60 GB SSD (`103.249.117.232:26567`) | K3s Server (Control Plane) | Ingress entrypoint, Cloudflare Tunnel |
| **Node 2** | VPS 4 Core / 8 GB RAM / 60 GB SSD (`103.249.117.201:26566`) | K3s Agent (Worker) | Dedicated PostgreSQL (`/srv/finsights-data`), Workers |
| **Storage** | 60 GB SSD cục bộ mỗi máy | Thư mục `/srv/finsights-data` | Local Path Provisioner cho K3s PVC |
| **Mạng nội bộ** | Tailscale VPN Mesh (`100.64.0.0/10`) | Interface `tailscale0` | Mã hóa toàn bộ inter-node pod/K3s traffic, NAT traversal |

---

## 2. Danh mục công việc (Worklist)

### Giai đoạn 1 — Quản lý truy cập & OS Hardening
- [x] Tạo cặp SSH key chuyên dụng `~/.ssh/finsights_vps` và cấu hình non-interactive access vào cả 2 VPS.
- [x] Cấu hình SSH daemon: `PermitRootLogin prohibit-password`, tắt password auth, bảo toàn cổng nội bộ `8686` và `22`.
- [x] Cấu hình UFW firewall: Deny inbound mặc định; chỉ mở các cổng SSH quản trị (`8686`, `22`, `26567`, `26566`), Tailscale (41641 UDP + interface `tailscale0`), K3s API `6443` (chỉ từ Tailscale network `100.64.0.0/10`), và pod/service CIDR của K3s.
- [x] Thiết lập đồng bộ thời gian NTP (`chrony`), tự động cập nhật bảo mật (`unattended-upgrades`), và giới hạn dung lượng log journald (512MB).

### Giai đoạn 2 — Mạng nội bộ Tailscale Mesh
- [x] Cài đặt Tailscale và cấu hình `net.ipv4.ip_forward=1`.
- [x] Tự động xác thực và kết nối vào Tailscale network với auth key.
- [x] Thiết lập interface `tailscale0` với DERP relay tự động vượt rào cản firewall/NAT của nhà cung cấp VPS.
- [x] Đo kiểm và xác nhận kết nối ping liên node qua mạng mã hóa Tailscale.

### Giai đoạn 3 — Cụm K3s Runtime & Storage
- [x] Cấu hình K3s Server trên Node 1 (`flannel-iface: tailscale0`, `node-ip: {{ tailscale_ip }}`).
- [x] Cấu hình K3s Agent trên Node 2 gia nhập cụm thông qua endpoint Tailscale `https://<node1-tailscale-ip>:6443`.
- [x] Tự động gán nhãn `node-role.kubernetes.io/worker=worker` và `database-node=true` cho Node 2.
- [x] Khởi tạo thư mục dữ liệu `/srv/finsights-data` với quyền `0750`.
- [x] Xuất `kubeconfig.yaml` để phục vụ kết nối cho repo Helm charts.

### Giai đoạn 4 — Tự động hóa CI/CD
- [x] Xây dựng GitHub Actions workflow `.github/workflows/infra-deploy.yml`.
- [x] Tự động hóa kiểm tra cú pháp và triển khai toàn bộ cấu hình qua Ansible.
- [x] Kiểm tra tình trạng sức khỏe cụm K3s sau khi deploy.
