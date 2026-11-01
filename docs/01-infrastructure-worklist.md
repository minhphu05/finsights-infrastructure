# Finsights Infrastructure & DevOps Worklist

**Trạng thái:** Triển khai hạ tầng Production 2-Node VPS  
**Cập nhật:** 01-11-2026  
**Kiến trúc:** 2 VPS (4 Core CPU, 8 GB RAM, 60 GB SSD mỗi máy)

## 1. Cơ sở và phạm vi

Phạm vi của `finsights-infrastructure` là thiết lập, hardening OS, firewall, WireGuard VPN mesh, Docker Engine và runtime K3s cho cụm 2 VPS. 

Repo này dừng lại ở ranh giới runtime máy chủ. Tất cả microservices, Backend API, Ingress/Cloudflare Tunnel, PostgreSQL container/StatefulSet, PVC và CronJobs sẽ được quản lý bằng Helm charts trong repo deployment riêng (`finsights-platform-deployment`).

### Cấu hình phần cứng

| Môi trường | Cấu hình máy chủ | Runtime | Ghi chú |
|---|---|---|---|
| **Node 1** | VPS 4 Core / 8 GB RAM / 60 GB SSD (`103.249.117.232:26567`) | K3s Server (Control Plane) | Ingress entrypoint, Cloudflare Tunnel |
| **Node 2** | VPS 4 Core / 8 GB RAM / 60 GB SSD (`103.249.117.201:26566`) | K3s Agent (Worker) | Dedicated PostgreSQL (`/srv/finsights-data`), Workers |
| **Storage** | 60 GB SSD cục bộ mỗi máy | Thư mục `/srv/finsights-data` | Local Path Provisioner cho K3s PVC |
| **Mạng nội bộ** | WireGuard VPN Mesh (`10.8.0.0/24`) | Interface `wg0` | Mã hóa toàn bộ inter-node pod/K3s traffic |

---

## 2. Danh mục công việc (Worklist)

### Giai đoạn 1 — Quản lý truy cập & OS Hardening
- [x] Tạo cặp SSH key chuyên dụng `~/.ssh/finsights_vps` và cấu hình non-interactive access vào cả 2 VPS.
- [x] Cấu hình SSH daemon: `PermitRootLogin prohibit-password`, tắt password auth, bảo toàn cổng nội bộ `8686` và `22`.
- [x] Cấu hình UFW firewall: Deny inbound mặc định; chỉ mở các cổng SSH quản trị (`8686`, `22`, `26567`, `26566`), WireGuard UDP `51820`, K3s API `6443` (chỉ từ dải WireGuard `10.8.0.0/24`), và pod/service CIDR của K3s.
- [x] Thiết lập đồng bộ thời gian NTP (`chrony`), tự động cập nhật bảo mật (`unattended-upgrades`), và giới hạn dung lượng log journald (512MB).

### Giai đoạn 2 — Mạng nội bộ WireGuard Mesh
- [x] Cài đặt WireGuard và cấu hình `net.ipv4.ip_forward=1`.
- [x] Tự động sinh cặp key mã hóa WireGuard trên từng node.
- [x] Thiết lập interface `wg0`: Node 1 (`10.8.0.1/24`), Node 2 (`10.8.0.2/24`) với `PersistentKeepalive = 25`.
- [x] Đo kiểm và xác nhận độ trễ inter-node cực thấp (~0.3 ms).

### Giai đoạn 3 — Cụm K3s Runtime & Storage
- [x] Cấu hình K3s Server trên Node 1 (`flannel-iface: wg0`, `node-ip: 10.8.0.1`).
- [x] Cấu hình K3s Agent trên Node 2 gia nhập cụm thông qua endpoint WireGuard `https://10.8.0.1:6443`.
- [x] Tự động gán nhãn `node-role.kubernetes.io/worker=worker` và `database-node=true` cho Node 2.
- [x] Khởi tạo thư mục dữ liệu `/srv/finsights-data` với quyền `0750`.
- [x] Xuất `kubeconfig.yaml` để phục vụ kết nối cho repo Helm charts.

### Giai đoạn 4 — Tự động hóa CI/CD
- [x] Xây dựng GitHub Actions workflow `.github/workflows/infra-deploy.yml`.
- [x] Tự động hóa kiểm tra cú pháp và triển khai toàn bộ cấu hình qua Ansible.
- [x] Kiểm tra tình trạng sức khỏe cụm K3s sau khi deploy.
