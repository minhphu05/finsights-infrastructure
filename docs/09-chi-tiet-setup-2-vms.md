# Báo cáo Chi tiết: Toàn bộ Thiết lập trên 2 VPS Trước khi Triển khai K3s

Tài liệu này tổng hợp chi tiết toàn bộ các thao tác, lệnh thực thi, cấu hình hệ điều hành và lý do triển khai trên **2 máy chủ VPS** (`Node 1` và `Node 2`) thuộc dự án **Finsights** trước và trong quá trình chạy CI/CD cài đặt K3s.

---

## 1. Thông tin ban đầu về 2 Máy chủ (VMs)

- **Nhà cung cấp:** Thuê VPS giá rẻ (`thuevpsgiare.com.vn`).
- **Hệ điều hành:** Ubuntu Server 24.04 LTS (x86_64 / amd64).
- **Cấu hình mỗi máy:** 4 vCPU, 8 GB RAM, 60 GB SSD.
- **Đặc điểm mạng (1:1 NAT):**
  - **Node 1 (Control Plane):** Public IP `103.249.117.232`, cổng SSH đối ngoại `26567` (NAT vào cổng nội bộ `8686`, IP nội bộ `16.0.0.175`).
  - **Node 2 (Worker + DB):** Public IP `103.249.117.201`, cổng SSH đối ngoại `26566` (NAT vào cổng nội bộ `8686`, IP nội bộ `17.0.0.218`).
  - *Lưu ý quan trọng:* Nhà cung cấp chặn toàn bộ các gói tin UDP đi vào từ bên ngoài (inbound UDP drop), chỉ cho phép đi qua các port TCP được NAT từ trước.

---

## 2. Các bước thiết lập ban đầu (Thực hiện thủ công từ máy quản trị)

### 2.1. Sinh cặp khóa SSH chuyên dụng Ed25519
- **Lệnh thực hiện trên máy cá nhân:**
  ```bash
  ssh-keygen -t ed25519 -C "admin@finsights-infrastructure" -f ~/.ssh/finsights_vps
  ```
- **Mục đích:** 
  - Tạo ra 1 cặp khóa định dạng Ed25519 hiện đại, bảo mật cao và gọn nhẹ.
  - Loại bỏ hoàn toàn việc đăng nhập bằng mật khẩu root (chống tấn công dò pass / brute-force).
  - Chuẩn bị file private key để đưa vào GitHub Actions Secret (`SSH_PRIVATE_KEY`) phục vụ CI/CD tự động.

### 2.2. Nạp Public Key vào 2 VPS
- **Lệnh thực hiện:**
  ```bash
  # Nạp vào Node 1 (Cổng 26567)
  ssh-copy-id -i ~/.ssh/finsights_vps.pub -p 26567 root@103.249.117.232

  # Nạp vào Node 2 (Cổng 26566)
  ssh-copy-id -i ~/.ssh/finsights_vps.pub -p 26566 root@103.249.117.201
  ```
- **Mục đích:** Đảm bảo Ansible và CI/CD có thể SSH vào tài khoản `root` của cả 2 VPS hoàn toàn tự động, non-interactive (không cần nhập mật khẩu).

### 2.3. Khảo sát tài nguyên & Kiểm tra bộ nhớ RAM thực tế
- **Lệnh thực hiện:**
  ```bash
  ssh -i ~/.ssh/finsights_vps -p 26567 root@103.249.117.232 "free -m; lscpu; df -h /"
  ssh -i ~/.ssh/finsights_vps -p 26566 root@103.249.117.201 "free -m; lscpu; df -h /"
  ```
- **Mục đích:**
  - Xác nhận chính xác thông số 4 vCPU và 60 GB SSD.
  - Làm rõ việc Dashboard nhà cung cấp báo RAM dùng cao (3.3GB / 2.2GB): Thực chất lệnh `free -m` cho thấy RAM thực sự sử dụng (Used) chỉ khoảng **0.7 GB - 1.2 GB**, phần còn lại là `buff/cache` của Linux Kernel để tăng tốc đĩa và hệ thống vẫn còn trống hơn **6.6 GB - 7.2 GB RAM thực tế** (`available`).

### 2.4. Dọn dẹp tàn dư kiến trúc Oracle Cloud và Roomify
- **Hành động:**
  - Xóa bỏ toàn bộ các file cấu hình Terraform, file key `.pem`, thư mục `.oci/`, `oracle-cloud/` từ dự án cũ.
  - Sửa đổi toàn bộ tên dự án và tài liệu từ Roomify sang **Finsights**.
- **Mục đích:** Tránh rò rỉ secret cũ, đảm bảo repository chỉ tập trung duy nhất vào kiến trúc 2-Node VPS của Finsights.

---

## 3. Các bước thiết lập hệ thống tự động qua Ansible

Khi chạy pipeline CI/CD (`site.yml`), hệ thống thực hiện lần lượt các role cấu hình sau trên cả 2 VPS:

### 3.1. Role `os_hardening` — Củng cố An ninh Hệ điều hành
1. **Cài đặt các gói tiện ích quản trị hệ thống:**
   - **Lệnh tương đương:**
     ```bash
     apt update && apt install -y curl ca-certificates gnupg jq net-tools ufw chrony unattended-upgrades
     ```
   - **Mục đích:** Cung cấp đầy đủ công cụ mạng, đồng bộ thời gian và cập nhật an ninh.
2. **Thiết lập múi giờ và đồng bộ thời gian (NTP):**
   - **Lệnh tương đương:**
     ```bash
     timedatectl set-timezone Asia/Ho_Chi_Minh
     systemctl enable --now chrony
     ```
   - **Mục đích:** Giúp log hệ thống, chứng chỉ SSL/TLS và các sự kiện của Kubernetes đồng bộ giờ chuẩn xác (`GMT+7`).
3. **Giới hạn dung lượng Log hệ thống (Systemd Journald):**
   - **Tạo file:** `/etc/systemd/journald.conf.d/60-finsights.conf`
     ```ini
     [Journal]
     SystemMaxUse=512M
     RuntimeMaxUse=256M
     MaxRetentionSec=1month
     ```
   - **Mục đích:** Giới hạn log tối đa 512 MB. Tránh trường hợp chạy lâu ngày log ghi đầy ổ cứng 60 GB SSD làm treo máy.
4. **Khóa chặt bảo mật SSH Daemon (`sshd`):**
   - **Tạo file:** `/etc/ssh/sshd_config.d/60-finsights.conf`
     ```text
     PermitRootLogin prohibit-password
     PasswordAuthentication no
     KbdInteractiveAuthentication no
     Port 8686
     Port 22
     ```
   - **Mục đích:** 
     - `PermitRootLogin prohibit-password` & `PasswordAuthentication no`: Chỉ cho phép đăng nhập bằng SSH key, chặn đứng 100% các cuộc tấn công brute-force dò mật khẩu qua internet.
     - Giữ nguyên cổng lắng nghe `8686` (cổng đích của NAT VPS) và `22`.
5. **Kích hoạt tự động cập nhật bản vá bảo mật:**
   - **Lệnh tương đương:** `dpkg-reconfigure -f noninteractive unattended-upgrades`
   - **Mục đích:** Tự động cài đặt các bản vá lỗi bảo mật (security patches) của Ubuntu mà không làm gián đoạn dịch vụ.

---

### 3.2. Role `storage_mount` — Chuẩn bị Thư mục Dữ liệu Bền vững
- **Lệnh tương đương:**
  ```bash
  mkdir -p /srv/finsights-data
  chmod 0750 /srv/finsights-data
  chown root:root /srv/finsights-data
  ```
- **Mục đích:** 
  - Khởi tạo thư mục `/srv/finsights-data` trên cả 2 máy với quyền hạn bảo mật `0750`.
  - Đây là nơi sẽ được gắn (mount) cho các PersistentVolumeClaim (PVC) của K3s thông qua Local Path Provisioner (đặc biệt là lưu trữ database PostgreSQL trên Node 2).

---

### 3.3. Role `tailscale` — Thiết lập Mạng Nội bộ Riêng (Private Mesh VPN)
*Đây là bước quan trọng nhất giải quyết vấn đề NAT và chặn UDP của nhà cung cấp VPS.*

1. **Bật tính năng chuyển tiếp gói tin (IPv4 Forwarding):**
   - **Lệnh tương đương:**
     ```bash
     sysctl -w net.ipv4.ip_forward=1
     echo "net.ipv4.ip_forward=1" >> /etc/sysctl.d/99-tailscale.conf
     ```
   - **Mục đích:** Cho phép Linux kernel chuyển tiếp các gói tin mạng giữa các interface (bắt buộc cho VPN và Kubernetes Pod networking).
2. **Cài đặt Tailscale chính thức:**
   - **Lệnh tương đương:**
     ```bash
     curl -fsSL https://tailscale.com/install.sh | sh
     systemctl enable --now tailscaled
     ```
   - **Mục đích:** Cài đặt phiên bản mới nhất của daemon `tailscaled`.
3. **Đăng nhập và gia nhập mạng nội bộ:**
   - **Lệnh tương đương:**
     ```bash
     tailscale up --authkey="tskey-auth-..." --hostname="finsights-prod-node-01" --accept-routes --reset
     ```
   - **Mục đích:**
     - Tự động xác thực qua Auth Key mà không cần đăng nhập qua trình duyệt.
     - Tạo ra interface mạng ảo `tailscale0`.
     - Tận dụng kỹ thuật **DERP Relay qua outbound HTTPS (TCP port 443)** của Tailscale để kết nối trực tiếp 2 VPS mà không bị tường lửa của nhà mạng chặn gói tin.
4. **Cấp phát IP Tailscale thu được:**
   - **Node 1:** `100.96.150.92`
   - **Node 2:** `100.79.12.34`
5. **Kiểm tra ping thông mạng:**
   - **Lệnh tương đương:**
     ```bash
     ping -c 3 100.96.150.92 # Từ Node 2
     ping -c 3 100.79.12.34 # Từ Node 1
     ```
   - **Mục đích:** Đảm bảo 2 máy đã thông mạng 100% trước khi cài đặt cụm Kubernetes.

---

### 3.4. Role `host_firewall` — Cấu hình Tường lửa Máy chủ (UFW)
1. **Thiết lập chính sách mặc định (Default Policy):**
   - **Lệnh tương đương:**
     ```bash
     ufw default deny incoming
     ufw default allow outgoing
     ```
   - **Mục đích:** Chặn toàn bộ các kết nối từ bên ngoài vào, chỉ mở những cổng được khai báo rõ ràng.
2. **Cấu hình UFW Forwarding cho Kubernetes:**
   - **Sửa file:** `/etc/default/ufw`
     ```text
     DEFAULT_FORWARD_POLICY="ACCEPT"
     ```
   - **Mục đích:** Khuyến nghị chuẩn của K3s/Kubernetes để Flannel CNI có thể forward các gói tin giữa các Pod trên các Node khác nhau mà không bị UFW chặn lại.
3. **Mở các cổng cần thiết:**
   - **Cổng SSH quản trị:** Mở TCP port `22`, `8686`, `26567`, `26566`.
   - **Mạng Tailscale:**
     - Cho phép toàn bộ traffic đi vào interface `tailscale0` (`ufw allow in on tailscale0`).
     - Mở cổng peer-to-peer UDP `41641`.
   - **K3s API Server (Cổng 6443):**
     - Chỉ cho phép truy cập từ dải mạng nội bộ Tailscale: `ufw allow from 100.64.0.0/10 to any port 6443 proto tcp`.
     - *Bảo mật:* Ngăn chặn người lạ từ internet quét và tấn công API Kubernetes.
   - **Dải mạng Pod & Service K3s:**
     - Mở dải IP Pod: `10.42.0.0/16`.
     - Mở dải IP Service: `10.43.0.0/16`.
4. **Kích hoạt UFW:**
   - **Lệnh tương đương:**
     ```bash
     ufw --force enable
     ```

---

### 3.5. Role `docker_engine` — Cài đặt Docker Engine & Docker Compose
1. **Thêm GPG key và kho phần mềm chính thức của Docker:**
   - **Lệnh tương đương:**
     ```bash
     curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
     echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable" > /etc/apt/sources.list.d/docker.list
     apt update
     ```
2. **Cài đặt các gói Docker:**
   - **Lệnh tương đương:**
     ```bash
     apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
     ```
3. **Cấu hình xoay vòng log cho Docker Daemon:**
   - **Tạo file:** `/etc/docker/daemon.json`
     ```json
     {
       "log-driver": "json-file",
       "log-opts": {
         "max-size": "10m",
         "max-file": "3"
       }
     }
     ```
   - **Mục đích:** Giới hạn mỗi container chạy bằng Docker (nếu có) chỉ lưu tối đa 3 file log, mỗi file 10MB để bảo toàn dung lượng đĩa.

---

## 4. Bảng tổng hợp các lệnh chính đã chạy trên 2 VPS

| Nhóm chức năng | Lệnh tiêu biểu | Mục đích cụ thể |
|---|---|---|
| **Truy cập & Xác thực** | `ssh-keygen -t ed25519`<br>`ssh-copy-id -p <port> root@<ip>` | Tạo và nạp SSH Key, bỏ đăng nhập mật khẩu root |
| **Kiểm tra tài nguyên** | `free -m`<br>`df -h`<br>`lscpu` | Xác minh 4 vCPU, 8 GB RAM (trống >6.6GB), 60 GB SSD |
| **Thời gian & Log** | `timedatectl set-timezone Asia/Ho_Chi_Minh`<br>`systemctl restart systemd-journald` | Set giờ GMT+7, giới hạn file log tối đa 512 MB |
| **Bảo mật SSH** | `PermitRootLogin prohibit-password`<br>`PasswordAuthentication no` | Chống dò pass SSH, chỉ mở quyền cho SSH Key |
| **Thư mục dữ liệu** | `mkdir -p /srv/finsights-data && chmod 0750 /srv/finsights-data` | Nơi lưu trữ persistent volume cho database và K3s |
| **Mạng Tailscale** | `sysctl net.ipv4.ip_forward=1`<br>`tailscale up --authkey=... --accept-routes` | Tạo mạng nội bộ riêng `tailscale0`, bypass NAT và firewall VPS |
| **Tường lửa UFW** | `ufw default deny incoming`<br>`ufw allow in on tailscale0`<br>`ufw allow from 100.64.0.0/10 to any port 6443` | Chặn toàn bộ bên ngoài, chỉ mở SSH và mạng nội bộ Tailscale |
| **Runtime Container** | `apt install docker-ce docker-compose-plugin` | Sẵn sàng Docker Engine nếu cần chạy các service nền độc lập |

---

## 5. Kết luận trạng thái trước khi cài K3s

Sau khi hoàn thành tất cả các bước trên:
1. Cả 2 máy chủ đã được **bảo vệ kiên cố** (chỉ có thể đăng nhập bằng SSH Key `~/.ssh/finsights_vps`).
2. Mạng nội bộ **Tailscale Mesh** đã hoạt động hoàn hảo, kết nối Node 1 (`100.96.150.92`) và Node 2 (`100.79.12.34`) với độ bảo mật mã hóa cao.
3. Hệ thống tài nguyên sạch sẽ, RAM trống hơn 85%, dung lượng đĩa có cơ chế chống tràn log.
4. Từ nền tảng này, CI/CD đã tự động cài đặt K3s Control Plane lên Node 1 và K3s Worker lên Node 2 mà không gặp bất kỳ lỗi kết nối hay timeout nào.
