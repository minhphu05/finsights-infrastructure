# Runbook: kiểm tra, khởi tạo và mount data volume

**Cảnh báo:** `mkfs.ext4` xóa dữ liệu trên thiết bị. Không dùng lệnh định dạng cho volume đang có dữ liệu.

## 1. Xác định đúng thiết bị

```bash
lsblk -f
sudo blkid /dev/vdb || true
findmnt /srv/finsights-data || true
```

So khớp block device trong `lsblk`. Nếu thiết bị không đúng hoặc chưa rõ volume nào được gắn, dừng.

## 2. Volume mới, được xác nhận trống

Role `storage_mount` mặc định không format. Sau khi xác nhận thiết bị là volume mới, chưa mount và không chứa dữ liệu cần giữ:

```bash
ansible-playbook ansible/playbooks/site.yml -e initialize_data_volume=true
```

Role tạo ext4 trực tiếp trên device path, lấy UUID và thêm mount theo UUID với `_netdev,nofail` tại `/srv/finsights-data`. Không truyền cờ này trong các lần chạy thường ngày.

## 3. Volume đã có filesystem

Nếu `blkid` tìm thấy ext4, chạy playbook mặc định:

```bash
ansible-playbook ansible/playbooks/site.yml
```

Role sẽ mount theo UUID và thất bại nếu filesystem khác `data_volume_filesystem`. Không tự format hoặc đổi filesystem để xử lý lỗi.

## 4. Kiểm tra sau mount/reboot

```bash
findmnt /srv/roomify-data
df -hP /srv/roomify-data
sudo grep -n '/srv/roomify-data' /etc/fstab
```

Sau khi lên kế hoạch downtime, reboot thử và xác nhận mount lại. Không dùng `nofail` làm lý do bỏ qua cảnh báo: nếu volume không gắn, dừng app stateful trước khi ghi vào thư mục rỗng trên boot volume.

## 5. Mở rộng dung lượng

OCI volume resize và filesystem resize là hai bước riêng. Trước khi tăng, tạo backup, kiểm tra free space/quota/chi phí, tăng size volume trong OCI, sau đó mở rộng filesystem theo đúng thiết bị và layout hiện tại. Runbook này không tự mở rộng phân vùng vì thiết kế mặc định format filesystem trực tiếp trên volume, không tạo partition.
