# Runbook: Hướng dẫn kết nối SSH an toàn vào 2 VPS

## 1. Thông tin kết nối SSH

- **Node 1 (Control Plane):**
  ```bash
  ssh -i ~/.ssh/finsights_vps -o IdentitiesOnly=yes -p 26567 root@103.249.117.232
  ```
- **Node 2 (Worker + DB):**
  ```bash
  ssh -i ~/.ssh/finsights_vps -o IdentitiesOnly=yes -p 26566 root@103.249.117.201
  ```

## 2. Tiêu chuẩn bảo mật SSH

- Cả 2 VPS đã được cài đặt public key của `~/.ssh/finsights_vps`.
- `sshd` được cấu hình `PermitRootLogin prohibit-password` (chặn toàn bộ tấn công brute-force password, chỉ cho phép SSH key).
- Cổng SSH nội bộ là `8686` và `22` (được NAT router chuyển tiếp ra ngoài qua cổng `26567` và `26566`).
- File private key cục bộ phải được đặt quyền bảo mật nghiêm ngặt:
  ```bash
  chmod 600 ~/.ssh/finsights_vps
  ```
