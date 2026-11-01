# Runbook: SSH access và cập nhật IP quản trị

## Kết nối

```bash
ssh -i ~/.ssh/roomify_oci ubuntu@<reserved-public-ip>
```

Private key phải được lưu cục bộ với quyền `0600`. OCI NSG và UFW chỉ cho SSH từ public IPv4 `/32` hiện hành. Không mở SSH từ `0.0.0.0/0`.

## Khi public IP quản trị thay đổi

1. Lấy public IPv4 mới và xác nhận định dạng `/32`.
2. Sửa `ssh_ingress_cidr` trong file tfvars của environment tương ứng.
3. Cập nhật Terraform trước; review plan để thấy đúng NSG SSH rule.
4. Apply rule mới và mở một terminal SSH mới để kiểm tra kết nối.
5. Chạy Ansible để cập nhật `admin_ssh_cidr` từ Terraform output vào generated inventory và đồng bộ UFW:

   ```bash
   ./scripts/render-ansible-inventory.sh prod
   ansible-playbook ansible/playbooks/site.yml
   ```

6. Chỉ sau khi kết nối mới hoạt động, xác nhận rule IP cũ đã bị loại khỏi NSG/UFW.

## Tạm thời không có IP cố định

Hạn chế SSH đến IP `/32` hiện tại, cập nhật khi IP thay đổi. Đối với vận hành lâu dài, chuyển sang VPN hoặc Bastion và điều chỉnh CIDR sau khi đã kiểm chứng đường vào mới. Không dùng `0.0.0.0/0` như giải pháp tiện lợi.
