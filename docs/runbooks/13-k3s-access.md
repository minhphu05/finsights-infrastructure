# Runbook: truy cập K3s an toàn

K3s API không được mở qua OCI NSG công khai. Truy cập từ host bằng `sudo k3s kubectl`; từ máy quản trị, dùng SSH port forwarding.

## Từ VM

```bash
sudo k3s kubectl get nodes -o wide
sudo k3s kubectl get pods -A
sudo systemctl status k3s --no-pager
sudo journalctl -u k3s -n 200 --no-pager
```

## Từ máy cá nhân qua SSH tunnel

Giữ tunnel mở ở terminal 1:

```bash
ssh -i ~/.ssh/roomify_oci -L 6443:127.0.0.1:6443 ubuntu@<reserved-public-ip>
```

Kubeconfig copy riêng và đổi server endpoint sang `https://127.0.0.1:6443`; giữ file permission `0600`. Không gửi kubeconfig/token qua chat, không commit, và đóng tunnel khi xong. Dùng đúng context và chỉ lấy kubeconfig qua kênh SSH đã xác thực.

Nếu API không hoạt động, kiểm tra service, localhost port 6443, `roomify_private_ip`, NSG/host firewall và node readiness. Không mở cổng 6443 ra Internet để chữa lỗi truy cập.
