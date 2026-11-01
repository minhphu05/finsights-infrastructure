# Finsights Infrastructure Backup & Disaster Recovery

**Mục tiêu khôi phục:** RTO ≤ 24 giờ và RPO ≤ 24 giờ.

## 1. Mô hình lỗi & Giảm thiểu rủi ro

Cụm gồm 2 VPS độc lập:
- **Node 1 (Control Plane):** Chạy K3s Server, Ingress, Cloudflare Tunnel. Nếu Node 1 gặp sự cố, có thể dựng lại K3s Server trên Node 1 mới hoặc thăng cấp Node 2.
- **Node 2 (Worker + DB):** Chạy PostgreSQL và Worker. Dữ liệu PostgreSQL nằm tại `/srv/finsights-data` (hoặc K3s Local PVC). 
- **Off-site Backup:** Bắt buộc phải sao lưu dữ liệu PostgreSQL và MinIO ra kho lưu trữ độc lập (Cloudflare R2, AWS S3 hoặc Google Cloud Storage) để phòng ngừa sự cố phần cứng VPS.

## 2. Ma trận sao lưu

| Thành phần | Dữ liệu cần giữ | Nơi lưu trữ an toàn | Trách nhiệm |
|---|---|---|---|
| **PostgreSQL Database** | Logical dump (`pg_dump`) nén và mã hóa hàng ngày | Cloudflare R2 / S3-compatible | `finsights-platform-deployment` (CronJob) |
| **Object Storage (MinIO)** | Media assets và tài liệu upload | S3 Bucket độc lập ngoài VPS | `finsights-platform-deployment` |
| **K3s Secrets & Config** | K3s node token, manifests, Helm values | Git repo deployment & Secret Manager | `finsights-platform-deployment` |
| **Hạ tầng máy chủ** | Cấu hình Ansible, SSH public keys, UFW rules | Repository `finsights-infrastructure` | `finsights-infrastructure` |

## 3. Quy trình khôi phục sự cố (Disaster Recovery)

1. **Khôi phục máy chủ VPS:**
   - Thuê hoặc khởi động lại VPS mới với cùng cấu hình (Ubuntu 24.04 LTS x86_64).
   - Cập nhật địa chỉ IP và SSH port vào [ansible/inventory/production.yml](file:///Users/kittnguyen/Documents/Project/Personal/finsights/finsights-infrastructure/ansible/inventory/production.yml).
2. **Triển khai hạ tầng tự động qua Ansible / CI-CD:**
   - Chạy workflow GitHub Actions `.github/workflows/infra-deploy.yml` hoặc chạy playbook `site.yml`.
   - Toàn bộ WireGuard mesh, K3s Server, K3s Agent và phân quyền `/srv/finsights-data` sẽ tự động được thiết lập lại từ đầu.
3. **Khôi phục ứng dụng & Dữ liệu:**
   - Chạy pipeline deploy từ repo Helm charts (`finsights-platform-deployment`).
   - Khôi phục bản dump PostgreSQL gần nhất từ Cloudflare R2 / S3.
   - Xác minh kết nối từ Vercel Frontend đến API endpoint Cloudflare Tunnel.
