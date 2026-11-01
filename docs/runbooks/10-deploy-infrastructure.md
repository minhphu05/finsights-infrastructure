# Runbook: triển khai hạ tầng Production

Runbook này tạo hạ tầng trống và chuẩn bị host. Nó không triển khai API, frontend, PostgreSQL, MinIO hoặc Redis containers.

## Trước khi chạy

- Xác nhận Production Home Region và compartment.
- Kiểm kê Compute, boot/data volumes, reserved/ephemeral IP và backups hiện có; không tạo trùng tài nguyên ghi trong sheet.
- Xác nhận roomify production image OCID là Ubuntu 24.04 ARM64 cho đúng region.
- Xác nhận A1 và tổng dung lượng volume còn trong quota; kiểm tra estimate và cost alerts.
- Cập nhật IP quản trị `/32`; xác nhận key pair.
- Có bản sao Terraform state được mã hóa và lưu ngoài máy chạy lệnh.

## Provision OCI

```bash
cd terraform/environments/prod
cp terraform.tfvars.example terraform.tfvars
# Sửa terraform.tfvars bằng các giá trị thật; không commit file này.
terraform init
terraform fmt -recursive ../../..
terraform plan -out=roomify-prod.tfplan
terraform show roomify-prod.tfplan
```

Đọc resource action, region, shape, boot/data volume, public IP và tất cả ingress rules. Nếu plan định tạo một VM mới trong khi VM 2/12/200 hiện hữu đã tồn tại, dừng và chuyển sang quy trình import/reconciliation. Chỉ apply plan đã kiểm tra:

```bash
terraform apply roomify-prod.tfplan
```

Lưu OCID/IP outputs trong nơi lưu vận hành phù hợp. Không đăng state/plan công khai.

## Chuẩn bị host

Từ repository root:

```bash
export ROOMIFY_SSH_PRIVATE_KEY="$HOME/.ssh/roomify_oci"
./scripts/render-ansible-inventory.sh prod
ansible-galaxy collection install -r ansible/requirements.yml
```

Kiểm tra `ansible/inventory/generated.yml` để xác nhận public/private IP và `/32`. Đối với volume mới hoàn toàn, xem [storage volume runbook](11-storage-volume.md), rồi chạy:

```bash
ansible-playbook ansible/playbooks/site.yml -e initialize_data_volume=true
```

Lần tiếp theo không dùng `initialize_data_volume=true`.

## Sau triển khai

```bash
ansible -m ping roomify_hosts
ansible-playbook ansible/playbooks/site.yml
```

Đăng nhập host, chạy `sudo ufw status verbose`, `sudo systemctl is-active docker k3s`, `sudo k3s kubectl get nodes -o wide`, `findmnt /srv/roomify-data`, và `./scripts/vm-healthcheck.sh`. Kiểm tra từ bên ngoài rằng TCP 6443, 5432, 6379, 9000 và 9001 không truy cập được.

## Drift và thay đổi

Sửa Terraform/Ansible trong repo, tạo plan mới, review rồi apply. Không sửa Console ngoài luồng rồi bỏ mặc drift. Thay đổi SSH CIDR cần kiểm tra session hiện tại và rule mới trước khi xóa IP cũ.
