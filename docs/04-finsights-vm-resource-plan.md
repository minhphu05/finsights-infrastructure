# Finsights: Kế hoạch phân bổ tài nguyên cụm 2 VPS

**Trạng thái:** Triển khai Production  
**Cập nhật:** 01-11-2026  
**Cấu hình:** 2 VPS (4 Core CPU, 8 GB RAM, 60 GB SSD mỗi máy)

## 1. Quyết định kiến trúc

- **Node 1 (Control Plane):** `103.249.117.232`, SSH Port `26567`, 4 vCPU, 8 GB RAM, 60 GB SSD. Đảm nhiệm K3s Server, Ingress routing, web traffic.
- **Node 2 (Worker + DB):** `103.249.117.201`, SSH Port `26566`, 4 vCPU, 8 GB RAM, 60 GB SSD. Đảm nhiệm K3s Agent, PostgreSQL database container, background workers.
- **Mạng nội bộ:** Tailscale VPN Mesh mã hóa (`tailscale0`). Mọi giao tiếp giữa K3s Server và Agent đều đi qua mạng mã hóa riêng biệt, tự động vượt qua giới hạn NAT của VPS.
- **Ranh giới repo:** `finsights-infrastructure` quản lý OS hardening, Docker Engine, K3s runtime, Tailscale VPN mesh và CI/CD. `finsights-platform-deployment` quản lý triển khai ứng dụng K3s và container.

## 2. Phân bổ RAM trên từng VPS (8 GB RAM mỗi máy)

### Node 1 (8 GB RAM) - Control Plane & Web Ingress
| Thành phần | Giới hạn RAM |
|---|---:|
| Ubuntu OS, Systemd, Logging | 1.0 GB |
| K3s Server & containerd | 1.5 GB |
| Traefik Ingress Controller | 0.5 GB |
| Web API Pods & Microservices | 3.0 GB |
| Headroom / Buffer OS cache | 2.0 GB |
| **Tổng** | **8.0 GB** |

### Node 2 (8 GB RAM) - Worker & Database
| Thành phần | Giới hạn RAM |
|---|---:|
| Ubuntu OS, Systemd, Logging | 1.0 GB |
| K3s Agent & containerd | 1.0 GB |
| PostgreSQL Database Container | 3.5 GB |
| Background Ingestion / Airflow Workers | 1.5 GB |
| Headroom / Buffer OS cache | 1.0 GB |
| **Tổng** | **8.0 GB** |
