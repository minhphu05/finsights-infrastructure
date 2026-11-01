# Runbook: Truy cập và quản trị cụm K3s an toàn

K3s API server lắng nghe trên cổng `6443` và được bảo vệ bởi UFW (chỉ cho phép truy cập qua mạng nội bộ WireGuard `10.8.0.0/24` hoặc localhost).

## 1. Truy cập trực tiếp từ Node 1 (Control Plane)

```bash
ssh -i ~/.ssh/finsights_vps -p 26567 root@103.249.117.232 "k3s kubectl get nodes -o wide"
ssh -i ~/.ssh/finsights_vps -p 26567 root@103.249.117.232 "k3s kubectl get pods -A"
```

## 2. Quản trị từ máy cá nhân qua SSH Port Forwarding

Mở SSH tunnel ở một cửa sổ terminal:

```bash
ssh -i ~/.ssh/finsights_vps -p 26567 -L 6443:127.0.0.1:6443 root@103.249.117.232
```

Sử dụng file `kubeconfig.yaml` được tạo ra sau khi chạy Ansible:
```bash
export KUBECONFIG="$(pwd)/kubeconfig.yaml"
kubectl get nodes
```

## 3. Quản trị từ repo Helm Charts (CI/CD)

- Cung cấp nội dung file `kubeconfig.yaml` cho GitHub Actions Secret của repo Helm (`KUBECONFIG_DATA`).
- Trong CI/CD của repo Helm, kết nối tới K3s API thông qua WireGuard runner hoặc SSH bastion port forwarding để chạy `helm upgrade --install`.
