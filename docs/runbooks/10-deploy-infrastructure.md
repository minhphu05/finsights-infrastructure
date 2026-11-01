# Runbook: Triển khai hạ tầng Finsights 2-Node VPS

Runbook này hướng dẫn cách cấu hình 2 VPS, mạng Tailscale mesh, và khởi tạo cụm K3s. Repo này chỉ quản lý hạ tầng và runtime K3s, không triển khai application containers (các container sẽ được deploy bằng Helm charts trong repo khác).

## 1. Thông tin 2 VPS

- **Node 1 (Control Plane):** `103.249.117.232`, SSH Port `26567`, user `root`.
- **Node 2 (Worker + DB):** `103.249.117.201`, SSH Port `26566`, user `root`.
- **SSH Key:** Private key tại `~/.ssh/finsights_vps` (đã nạp public key vào `/root/.ssh/authorized_keys` của cả 2 máy).
- **Tailscale Auth Key:** Auth key tạo từ Tailscale Admin Console (Reusable) được lưu trong Secret `TAILSCALE_AUTHKEY`.

## 2. Triển khai tự động qua GitHub Actions CI/CD (Khuyến nghị)

1. Cài đặt 2 GitHub Secrets:
   - `SSH_PRIVATE_KEY`: Nội dung file `~/.ssh/finsights_vps`.
   - `TAILSCALE_AUTHKEY`: Reusable Auth Key từ Tailscale.
2. Đẩy code lên nhánh `main` của repository GitHub:
   ```bash
   git push origin main
   ```
3. Workflow [.github/workflows/infra-deploy.yml](file:///Users/kittnguyen/Documents/Project/Personal/finsights/finsights-infrastructure/.github/workflows/infra-deploy.yml) sẽ tự động kích hoạt:
   - Cài đặt Ansible & các collections.
   - Nạp secrets `SSH_PRIVATE_KEY` và `TAILSCALE_AUTHKEY`.
   - Chạy `ansible-playbook -i ansible/inventory/production.yml ansible/playbooks/site.yml`.
   - Kết nối 2 VPS qua Tailscale mesh (`tailscale0`), khởi tạo K3s server & agent.
   - Gắn nhãn các node và kiểm tra trạng thái cụm K3s.

## 3. Triển khai thủ công từ máy quản trị (Local)

Nếu cần chạy trực tiếp từ máy cục bộ:

```bash
# 1. Cài đặt các collection yêu cầu
ansible-galaxy collection install -r ansible/requirements.yml

# 2. Xuất biến môi trường
export ANSIBLE_SSH_KEY_FILE="~/.ssh/finsights_vps"
export TAILSCALE_AUTHKEY="<tskey-auth-...>"

# 3. Kiểm tra kết nối tới 2 VPS
ansible -i ansible/inventory/production.yml -m ping finsights_hosts

# 4. Thực thi playbook triển khai
ansible-playbook -i ansible/inventory/production.yml ansible/playbooks/site.yml
```

## 4. Kiểm tra sau triển khai

Kiểm tra trạng thái cụm K3s từ Node 1:
```bash
ssh -i ~/.ssh/finsights_vps -p 26567 root@103.249.117.232 "k3s kubectl get nodes -o wide"
```

Kết quả mong đợi: Cả 2 nodes (`finsights-prod-node-01` và `finsights-prod-node-02`) đều ở trạng thái `Ready`, với interface `tailscale0` kết nối mạng nội bộ bảo mật.
