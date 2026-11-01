# Roomify Infrastructure & DevOps Worklist

**Trạng thái:** Worklist đề xuất cho MVP/beta  
**Ngày:** 11-10-2026  
**Mục tiêu tải:** khoảng 10 người dùng đồng thời; chưa tối ưu cho tăng trưởng lớn.

## 1. Cơ sở và phạm vi

Worklist đã được cập nhật theo các ô Review của Sheet `01 - Infrastructure Plan` ngày 11-10-2026. Sheet đánh dấu INF-001/002 Hoàn tất và INF-003/004 Chưa bắt đầu; các giá trị Review được ghi dưới đây. Checkbox trong worklist theo dõi triển khai thực tế, không khẳng định các cấu hình cloud đã tồn tại. Home Region chính xác, image OCID, domain, IP quản trị và backup operator vẫn cần xác nhận trước khi apply.

Phạm vi của `roomify-infrastructure` là tạo và chuẩn bị OCI resources, VM, mạng, ổ đĩa, OS, firewall, Kubernetes runtime, health checks, benchmark và runbooks. Repo này không triển khai PostgreSQL, MinIO, Redis, API hay frontend; các định nghĩa container/Compose của PostgreSQL, MinIO và Redis thuộc `roomify-platform-deployment`, nhưng các container này chạy ngoài K3s trên cùng VM. Go API, ingress/TLS và asset worker chạy trong K3s. Schema/migration/seed thuộc `roomify-core-db`.

### Cấu hình nền để lập kế hoạch

| Môi trường | Compute đề xuất | Runtime | Ghi chú |
|---|---|---|---|
| Prod | OCI Ampere A1 Flex, ARM64, 2 OCPU / 12 GB RAM | Một node K3s, control plane và workloads cùng node | Tạo ở home region; không có HA |
| Dev tạm thời | VM A1 riêng, 2 OCPU / 12 GB nếu dùng đúng cấu hình mẫu | Một node K3s để kiểm thử | Tài nguyên trial trả phí; tách state/network/secret, có ngày xóa |
| Storage Prod | Boot 50 GB + data volume 150 GB = 200 GB tổng | Data mount tại `/srv/roomify-data` | Tính boot volume vào tổng 200 GB; xác nhận mức tối thiểu của image trước khi tạo |

Topology đã chốt trong Review INF-002 là một A1 VM chạy K3s single-node. PostgreSQL và MinIO là container Docker ngoài cluster, không phải Kubernetes workloads; Redis có thể tắt. Cấu hình này tối ưu chi phí và vận hành đơn giản, nhưng không có HA và VM là failure domain chung cho web, API và dữ liệu.

## 2. Worklist theo thứ tự triển khai

### Giai đoạn 0 — Chốt đầu vào kiến trúc (P0, chặn trước khi tạo tài nguyên)

- **INF-001 — Xác minh hạn mức và vùng triển khai (Review sheet: Hoàn tất).** Review ghi nhận A1 Always Free 2 OCPU / 12 GB tổng, 200 GB gồm boot + block volume; VM ghi trong sheet dùng 2/12/200. Trước khi tạo, xác nhận Home Region thật, số lượng tài nguyên hiện có, Reserved/Ephemeral IP và entitlement ở OCI. URL `ap-tokyo-1` chỉ cho biết region đang xem, không xác nhận Home Region.
- **INF-002 — Chốt topology Kubernetes (Review sheet: Hoàn tất).** Một VM A1 chạy K3s single-node; Go API, ingress/TLS và asset worker ở K3s; PostgreSQL và MinIO chạy container bên ngoài K3s trên cùng máy; Redis optional. Boot 50 GB + data 150 GB; dành 30 GB Postgres, 105 GB MinIO, 5 GB temp/logs, 10 GB reserve. DB/MinIO chỉ mạng nội bộ; backup đặt ngoài VM.
- [ ] **INF-003 — Chốt image OS/CPU (review đã ghi lựa chọn).** Ubuntu Server 24.04 LTS ARM64 (`aarch64`), Canonical OCI Platform Image hiện hành; giữ OCI Agent mặc định và xác minh mọi image/runtime tương thích ARM64. Terraform gửi cloud-init để cài prerequisite tối thiểu; Ansible quản lý cấu hình host có thể chạy lại. Trước apply, xác minh image OCID khớp region và vẫn là image Ubuntu 24.04 ARM64.
- [ ] **INF-004 — Chốt truy cập và khôi phục (review đã ghi lựa chọn).** Domain `roomify.<your-domain>` còn TBD; tạm dùng Reserved Public IP, SSH chỉ từ IP quản trị `/32`; không mở `0.0.0.0/0` cho SSH. RTO/RPO mục tiêu đều ≤24 giờ; primary operator là project owner, backup operator cần chỉ định. DNS Cloudflare A record trỏ Reserved IP khi domain sẵn sàng; trước đó test qua IP với HTTPS/ingress được kiểm soát.
- [ ] **INF-005 — Chốt ranh giới workload.** Infrastructure quản lý OCI, OS, host firewall, mount, Docker/K3s runtime. `platform-deployment` quản lý application manifests/Compose, ingress/TLS và service containers. `core-db` quản lý schema/migrations/seeds.

**Điều kiện qua giai đoạn:** topology, home region, OS, DNS và quyền quản trị đã được ghi lại; không triển khai theo giả định “Tokyo là home region” chỉ vì Console đang chọn `ap-tokyo-1`.

### Giai đoạn 1 — Quản trị OCI, chi phí và Infrastructure as Code (P0)

- [ ] **INF-010 — Tổ chức tài nguyên.** Tạo/chuẩn hóa compartment cho Roomify; tách nhãn `prod` và `dev`; thêm tag môi trường, owner, mục đích và hạn xóa cho tài nguyên Trial.
- [ ] **INF-011 — IAM tối thiểu.** Bật MFA cho truy cập Console; tạo quyền riêng cho người/identity chạy Terraform, giới hạn đúng compartment và loại tài nguyên cần quản lý. Không dùng credential quản trị tenancy trong CI.
- [ ] **INF-012 — Bảo vệ Terraform state và secrets.** Chọn backend state có kiểm soát truy cập/phiên bản hoặc phương án local được mã hóa và sao lưu; xác nhận cách khóa state khi nhiều lần chạy. Thêm state, private key, kubeconfig, API signing key và `.env` thật vào ignore rules; không commit chúng.
- [ ] **INF-013 — Chuẩn hóa Terraform.** Tạo module `network`, `compute`, `storage`; tách `environments/dev` và `environments/prod`; pin phiên bản Terraform/provider; xuất output cần thiết (subnet, NSG, IP, volume ID) mà không xuất secrets.
- [ ] **INF-014 — Đặt quy trình thay đổi.** CI hoặc quy trình nội bộ chạy `fmt`, `validate`, kiểm tra policy/secret và tạo plan để review trước apply. Prod chỉ apply khi plan đã được kiểm tra; ghi cách xử lý drift và rollback.
- [ ] **INF-015 — Cảnh báo chi phí.** Tạo budget/alerts theo các mốc 50%, 75%, 90% và 100% của khoản Trial; kiểm tra Cost Analysis thường xuyên và lập danh sách tài nguyên phải xóa. Alert không thay cho hard spending cap hoặc quy trình dừng/xóa.

**Điều kiện qua giai đoạn:** state không nằm trong Git; principal Terraform không có quyền dư; plan prod và dev được tách biệt; có cách xem chi phí và ngày hết hạn Trial.

### Giai đoạn 2 — VCN, route, OCI Firewall/NSG và DNS (P0)

- [ ] **INF-020 — Tạo VCN và subnet.** Chọn CIDR không trùng mạng nhà/VPN cần kết nối; tạo route table và Internet Gateway nếu VM nhận traffic web công khai. Với một VM MVP, dùng topology đơn giản; chưa tạo NAT Gateway hoặc OCI Load Balancer nếu chưa có nhu cầu và ngân sách được xác nhận.
- [ ] **INF-021 — Tạo NSG theo môi trường.** Tạo NSG riêng cho prod và dev, gắn vào VNIC của VM. Kiểm tra security list mặc định của subnet để không vô tình mở rộng traffic ngoài NSG.
- [ ] **INF-022 — Viết ma trận ingress/egress.** Mặc định deny inbound; chỉ mở TCP 80/443 từ Internet khi dịch vụ công khai; TCP 22 chỉ từ IP quản trị cố định hoặc đường truy cập quản trị đã chọn; K3s API không mở trên NSG công khai (quản trị qua SSH tunnel hoặc private VCN). DNS, HTTPS đến registry/package endpoints và NTP chỉ mở theo nhu cầu vận hành.
- [ ] **INF-023 — Giữ cổng nội bộ khỏi Internet.** Không mở PostgreSQL 5432, Redis 6379, MinIO API/console, kubelet, NodePort range, K3s VXLAN/overlay hoặc control-plane datastore ra Internet. Nếu chọn nhiều node, chỉ cho phép đúng traffic K3s giữa các private IP của node.
- [ ] **INF-024 — Tách Dev khỏi Prod.** Tách NSG (và subnet nếu cần); không cho Dev truy cập database/MinIO Prod; không tái sử dụng secret prod trong Dev.
- [ ] **INF-025 — Public IP và DNS.** Ghi lại public IP/reservation, DNS A/AAAA record và TTL; chỉ trỏ domain sau khi ingress/TLS sẵn sàng. Xác định ai sở hữu việc gia hạn DNS/domain.

**Điều kiện qua giai đoạn:** có bảng rule với source, destination, port, protocol, lý do và môi trường; không có rule quản trị hoặc data-plane mở `0.0.0.0/0` ngoài HTTP/HTTPS có chủ đích.

### Giai đoạn 3 — Compute, boot/data volume và Linux OS (P0)

- [ ] **INF-030 — Tạo VM Prod.** Dùng A1 Flex ARM64, tối đa 2 OCPU / 12 GB RAM trong home region; xác nhận tổng A1 của tenancy và eligibility trước apply. Gắn SSH key khi tạo; không bật password login.
- [ ] **INF-031 — Tạo VM Dev có thời hạn.** Chỉ tạo khi có job cụ thể; dự toán chi phí, gắn tag hết hạn, ghi người chịu trách nhiệm dọn dẹp và ngày teardown. Không tính VM Dev vào hạn mức Always Free của Prod.
- [ ] **INF-032 — Chọn boot volume.** Kiểm tra boot volume tối thiểu và dung lượng mặc định của image. Cấu hình boot size để tổng boot + data volume Prod không vượt 200 GB nếu mục tiêu là nằm trong quota Always Free.
- [ ] **INF-033 — Gắn data volume riêng.** Đề xuất 150 GB cho Prod sau boot volume 50 GB. Xác nhận encryption/performance; format bằng filesystem được hỗ trợ, mount theo UUID tại `/srv/roomify-data`, cấu hình tự mount sau reboot và kiểm tra quyền owner/group.
- [ ] **INF-034 — Phân vùng ngân sách đĩa.** Dành hạn mức dự kiến cho PostgreSQL/WAL, MinIO objects, upload tạm, logs và phần dự phòng; phát cảnh báo khi volume đạt 70%, hành động khẩn trước 85%. Không đặt data chính chỉ trên boot volume.
- [ ] **INF-035 — Hardening tài khoản/SSH.** Tạo user quản trị riêng có sudo; vô hiệu hóa SSH root và password; giới hạn SSH bằng NSG + host firewall; bảo vệ private key ngoài repo; rà soát quyền sudo và người dùng tồn tại.
- [ ] **INF-036 — Patch và baseline OS.** Cập nhật security patches; đồng bộ thời gian; dùng `Asia/Ho_Chi_Minh` cho host logs và UTC cho timestamp ứng dụng; cấu hình repository/package policy, unattended security updates hoặc lịch patch; tắt dịch vụ không cần; ghi quy trình reboot và kiểm tra sau reboot.
- [ ] **INF-037 — Quản lý log và hệ thống.** Bật log rotation/journald limits, lưu audit hệ thống cần thiết, kiểm tra dung lượng `/var` và data volume; tránh log không giới hạn làm đầy ổ.

**Điều kiện qua giai đoạn:** VM khởi động lại thành công; data volume mount tự động; SSH key-only hoạt động; tổng volume và shape được đối chiếu với quota/chi phí.

### Giai đoạn 4 — OS Firewall và cài K3s runtime (P0)

- [ ] **INF-040 — Chọn một nguồn cấu hình host firewall.** Dùng UFW hoặc nftables/firewalld theo OS; không duy trì các bộ rule iptables thủ công song song. Viết rõ cách giữ traffic CNI/K3s cần thiết để firewall host không phá cluster networking.
- [ ] **INF-041 — Đồng bộ host firewall với NSG.** Đặt inbound mặc định deny; cho SSH từ nguồn quản trị và 80/443 khi cần; mở traffic node-to-node chỉ trong subnet/private IP nếu chọn cluster nhiều node. Ghi cách kiểm tra sau mỗi lần cập nhật K3s/OS.
- [ ] **INF-042 — Cài runtime theo workload boundary.** Cài K3s ARM64 với containerd đi kèm cho API/ingress/asset worker; cài Docker Engine riêng cho các container Postgres/MinIO/Redis chạy ngoài K3s. Dùng host network và bind private IP để pod kết nối với service mà không dựa vào Docker bridge port publishing; ghi phiên bản và cách nâng cấp từng runtime.
- [ ] **INF-043 — Bảo vệ control plane.** Giới hạn API 6443 theo NSG/host firewall; bảo vệ kubeconfig và node token như secrets; đặt TLS SAN cho địa chỉ quản trị cần dùng; không commit kubeconfig/token vào Git hoặc log.
- [ ] **INF-044 — Cấu hình node một máy.** Để node K3s vừa là server vừa nhận workload theo topology đã chốt; giữ đủ CPU/RAM/disk cho OS và K3s. Xác minh node và system pods trở lại Ready sau reboot.
- [ ] **INF-045 — Chuẩn bị persistent storage.** Infrastructure mount data volume theo UUID tại `/srv/roomify-data`; không format lại volume có filesystem. `platform-deployment` ánh xạ Docker bind mounts cho PostgreSQL/MinIO vào các thư mục con, đặt ownership phù hợp và kiểm soát không public port.
- [ ] **INF-046 — Đặt resource budget.** Giữ headroom cho OS/K3s; workload manifests ở `platform-deployment` phải có CPU/memory requests/limits. Giới hạn concurrency của worker/scraper; không chạy render/AI nặng đồng thời với API/database trên Prod.
- [ ] **INF-047 — Xác minh ARM64 end-to-end.** Kiểm tra mọi image, native dependency, migration tool và CI artifact có build/run `linux/arm64`; image không tương thích phải bị chặn trước deploy.
- [ ] **INF-048 — Sao lưu cấu hình K3s.** Ghi vị trí K3s server state, node token, kubeconfig, manifests hạ tầng và cách dựng lại cluster từ Terraform/Ansible. Lưu bản backup mã hóa tách khỏi VM.

**Điều kiện qua giai đoạn:** K3s Ready; host firewall và NSG không chặn traffic thiết yếu; API không phơi công khai; cấu hình/cách khôi phục được lưu trong repo.

### Giai đoạn 5 — Ansible, bảo mật và vận hành thường ngày (P1)

- [ ] **INF-050 — Tạo Ansible roles/playbooks có thể chạy lại.** Tách role OS hardening, SSH, host firewall, volume mount và K3s runtime; dùng inventory riêng cho prod/dev; secrets lấy từ secret store hoặc vault được bảo vệ.
- [ ] **INF-051 — Tạo runbook truy cập.** Hướng dẫn thêm/thu hồi SSH key, cập nhật IP quản trị, truy cập K3s an toàn, xử lý mất quyền truy cập và xoay credential. Không đưa key/password thật vào ví dụ.
- [ ] **INF-052 — Thiết lập kiểm tra sức khỏe VM.** `vm-healthcheck.sh` báo CPU/load, RAM khả dụng, filesystem/dung lượng mount, trạng thái Docker/K3s và node Ready; script chỉ đọc trạng thái, không tự thay đổi tài nguyên OCI. Nếu sau này cần kiểm tra inode hoặc endpoint dịch vụ, bổ sung health check theo port/URL đã chốt ở repo deployment.
- [ ] **INF-053 — Thiết lập giám sát nhẹ.** Chọn OCI Monitoring/Logging hoặc giải pháp nhẹ phù hợp quota; cảnh báo VM down, disk 70%/85%, memory pressure, CPU bão hòa kéo dài và lỗi volume mount. Tránh dựng stack Prometheus/Grafana nặng trên cùng VM nếu chưa đo được headroom.
- [ ] **INF-054 — Lập chính sách retention.** Quy định log retention/rotation, thời hạn giữ backup, snapshot và export; không ghi token, password, PII hoặc payload nhạy cảm vào log.
- [ ] **INF-055 — Kiểm tra Audit và drift.** Định kỳ xem thay đổi VCN/NSG/route/IAM và so sánh tài nguyên Console với Terraform; mọi sửa đổi thủ công cần được đưa ngược về IaC hoặc hoàn nguyên.

### Giai đoạn 6 — Backup, restore, benchmark và DR (P1, trước beta)

- [ ] **INF-060 — Chốt backup matrix với Platform Deployment.** Xác định riêng: PostgreSQL logical/physical backup; MinIO/object backup hoặc replication/export; cấu hình K3s/Ansible/Terraform; boot/data volume snapshots. Không coi snapshot cùng tenancy/VM là bản sao duy nhất.
- [ ] **INF-061 — Lưu bản sao ngoài failure domain.** Mã hóa backup và giữ ít nhất một bản ngoài VM nguồn; với Dev/Trial, export dữ liệu cần giữ ra kho độc lập trước khi hết hạn. Xác nhận dung lượng và chi phí của nơi lưu đó.
- [ ] **INF-062 — Diễn tập restore.** Khôi phục thử database, object và cluster/config vào môi trường riêng; ghi thời gian, bước lỗi, checksum và kết quả; cập nhật `docs/08-disaster-recovery.md`.
- [ ] **INF-063 — Chạy benchmark có giới hạn.** `benchmark.sh` dùng kịch bản được chuẩn bị, giới hạn thời lượng/concurrency và ghi phiên bản commit/config. Đo API p95/5xx (phối hợp backend), CPU/RAM, PostgreSQL connection/slow query, upload MinIO, disk growth và queue depth.
- [ ] **INF-064 — Kiểm chứng tải mục tiêu.** Thử 10 user đồng thời và ghi baseline trước beta; không có OOM/restart ngoài dự kiến; xác nhận disk dưới 70% ở bộ dữ liệu mẫu và có headroom RAM. Chốt ngưỡng p95/error rate với chủ sản phẩm/backend thay vì tự đặt SLO trong infra.
- [ ] **INF-065 — Viết runbook khôi phục dịch vụ.** Gồm recreate network/VM, gắn data volume hoặc restore backup, dựng K3s, deploy qua `platform-deployment`, kiểm tra health, cập nhật DNS và thông báo bảo trì.

### Giai đoạn 7 — Dev Trial và teardown (P1, áp dụng khi tạo VM Dev)

- [ ] **INF-070 — Tạo Dev sau khi chuẩn bị xong workload.** Hoàn thành scripts, image, input data và benchmark trước khi bật VM để tránh tiêu credit cho cài đặt chờ.
- [ ] **INF-071 — Cô lập Dev.** Dùng NSG riêng; chỉ dữ liệu tổng hợp/được phép; không dùng production credentials; giới hạn SSH/HTTPS và không public database/MinIO admin.
- [ ] **INF-072 — Theo dõi chi phí Dev.** Ghi estimate trước khi create; bật alert; theo dõi Compute, boot/data volumes, backups, IP và dịch vụ phụ trợ. Dừng hoặc xóa theo lịch khi job hoàn tất; OS shutdown không thay cho quy trình OCI Stop/Destroy.
- [ ] **INF-073 — Export và xác nhận artifacts.** Kiểm checksum cho database dump, objects, render/dataset và reports; kiểm thử đọc/restore từ nơi lưu độc lập trước khi teardown.
- [ ] **INF-074 — Xóa tài nguyên trả phí đúng hạn.** Hủy instance Dev cùng boot/data volumes, backups/snapshots, public IP và tài nguyên riêng khác không còn cần; xác nhận không còn resource bị bỏ quên trong compartment và Cost Analysis giảm về mức dự kiến.

## 3. Ma trận trách nhiệm giữa các repo

| Hạng mục | Owner chính | Phạm vi |
|---|---|---|
| VCN, subnet, route, IGW, NSG, public IP, VM, block volume | `roomify-infrastructure` | Terraform và tài nguyên OCI |
| Linux, SSH, UFW/nftables, mount, K3s base, healthcheck | `roomify-infrastructure` | Ansible, scripts, OS/runbooks |
| Namespace, ingress controller config, TLS, app/database/MinIO/Redis manifests, PVC | `roomify-platform-deployment` | Workload chạy trên cluster; phối hợp mount contract với infra |
| Schema, migrations, constraints, seed data | `roomify-core-db` | Nội dung database, không quản lý VM/volume |
| ARM64 container images và runtime behavior | `roomify-backend`, `roomify-frontend`, `roomify-ai` | Build/publish image và yêu cầu tài nguyên ứng dụng |

## 4. Tiêu chí sẵn sàng đưa Prod vào beta

- [ ] Terraform plan không có thay đổi ngoài dự kiến; tài nguyên Prod nằm đúng compartment, region và quota.
- [ ] Từ Internet chỉ có web ingress cần thiết; SSH và Kubernetes API giới hạn cho quản trị; PostgreSQL, Redis, MinIO và NodePort không mở công khai.
- [ ] OS được harden, cập nhật, truy cập bằng key; UFW/nftables và OCI NSG đã kiểm tra cùng với K3s.
- [ ] Data volume tự mount sau reboot; cảnh báo dung lượng hoạt động; log rotation không làm đầy ổ.
- [ ] K3s và node khôi phục Ready sau reboot; images cần thiết chạy trên ARM64.
- [ ] Backup nằm ngoài VM và restore đã diễn tập; có runbook khôi phục.
- [ ] Benchmark 10 người dùng đồng thời đã ghi kết quả, bottleneck và giới hạn concurrency; không đặt mục tiêu vượt quá 2 OCPU / 12 GB / 200 GB.
- [ ] Dev Trial có TTL/teardown checklist; không còn secret hoặc dữ liệu cần giữ chỉ nằm trên tài nguyên Trial.

## 5. Tài liệu tham khảo

- [K3s networking requirements](https://docs.k3s.io/installation/requirements) — cổng cần cho node và traffic overlay; mở nội bộ theo topology.
- [K3s security hardening guide](https://docs.k3s.io/security/hardening-guide) — hướng dẫn bảo vệ cluster và workload.
- [WireGuard Quick Start](https://www.wireguard.com/quickstart/) — cấu hình VPN mesh bảo mật giữa các node VPS.
- Repo nội bộ: [`04-roomify-vm-resource-plan.md`](04-roomify-vm-resource-plan.md), [`05-vm-specification.md`](05-vm-specification.md), [`02-repository-structure.md`](02-repository-structure.md).
