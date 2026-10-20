# TÀI LIỆU TỔNG HỢP PHỤC VỤ VIẾT BÁO CÁO ĐỒ ÁN CHUYÊN ĐỀ
### Đề tài: Triển khai và Quản trị Hệ thống Đặt phòng Khách sạn trên Môi trường Linux Ubuntu Server

- **Sinh viên thực hiện**: Quách Anh Tuấn
- **Mã số sinh viên**: DTC245180025
- **Email**: narukun2812@gmail.com
- **Repository**: `DTC245180025-hotel-devops`
- **Địa chỉ máy chủ (VM)**: `192.168.186.130` (Ubuntu Server 24.04 LTS)

---

## BẢNG THÀNH PHẦN VÀ PHIÊN BẢN THỰC TẾ TRONG HỆ THỐNG

| STT | Thành phần | Hình ảnh Docker (Image & Tag cố định) | Cổng nội bộ | Phân vùng mạng | Vai trò & Mục đích sử dụng |
|:---:|---|---|---|---|---|
| 1 | **Reverse Proxy** | `nginx:1.27.1-alpine` | `80`, `443` (Public host) | `frontend`, `monitoring` | Cổng vào duy nhất của hệ thống, chuyển hướng HTTP sang HTTPS, SSL Termination, bảo mật HTTP headers, Rate Limiting chống Brute Force. |
| 2 | **Web Application** | `hotel-web` (`node:20.18.0-alpine3.20`) | `3000` | `frontend`, `backend` | Ứng dụng web đặt phòng viết bằng Node.js 20, Express, EJS SSR, kết nối PostgreSQL qua pool. Chạy dưới quyền `node` (UID 1000). |
| 3 | **Database** | `postgres:16.4-alpine3.20` | `5432` | `backend` (`internal: true`) | Cơ sở dữ liệu quan hệ lưu trữ dữ liệu người dùng, phòng, dịch vụ, đặt phòng và thanh toán. Áp dụng least-privilege cho `hotel_app`. |
| 4 | **DB Admin** | `dpage/pgadmin4:8.11` | `80` (proxy /pgadmin/) | `frontend`, `backend` | Giao diện đồ họa quản trị CSDL PostgreSQL trực quan dưới đường dẫn con `/pgadmin/`. Chạy dưới quyền `pgadmin` (UID 5050). |
| 5 | **Metrics Collector**| `prom/prometheus:v2.54.1` | `9090` | `monitoring` | Máy chủ thu thập số liệu giám sát (metrics), lưu trữ dữ liệu chuỗi thời gian (time-series TSDB). Chạy dưới quyền `nobody` (UID 65534). |
| 6 | **Visualization** | `grafana/grafana:11.2.0` | `3000` (proxy /grafana/) | `frontend`, `monitoring` | Trực quan hóa số liệu qua 4 Dashboards chuyên sâu và quản lý quy tắc cảnh báo sự cố an ninh. Chạy dưới quyền `grafana` (UID 472). |
| 7 | **Container Metrics**| `gcr.io/cadvisor/cadvisor:v0.49.1` | `8080` | `monitoring` | Giám sát mức tiêu thụ tài nguyên phần cứng (CPU %, RAM, Disk I/O, Network I/O) của toàn bộ 12 containers. |
| 8 | **Nginx Exporter** | `nginx/nginx-prometheus-exporter:1.3.0` | `9113` | `frontend`, `monitoring` | Thu thập thông số lưu lượng mạng, kết nối đồng thời và request rate từ Nginx `stub_status`. Chạy dưới quyền `nobody` (UID 65534). |
| 9 | **Postgres Exporter**| `prometheuscommunity/postgres-exporter:v0.15.0`| `9187` | `backend`, `monitoring` | Thu thập thông số nội bộ CSDL PostgreSQL (kết nối, giao dịch/giây, cache hit ratio, deadlocks). Chạy dưới quyền `nobody` (UID 65534). |
| 10 | **Log Storage** | `grafana/loki:3.1.1` | `3100` | `monitoring` | Kho lưu trữ và lập chỉ mục nhật ký (log) tập trung. Chạy dưới quyền `loki` (UID 10001). |
| 11 | **Log Shipper** | `grafana/promtail:3.1.1` | - | `monitoring` | Agent thu thập nhật ký từ Docker daemon engine, bóc tách nhãn và chuyển tiếp theo luồng thời gian thực về Loki. |
| 12 | **Alert Sink** | `hotel-alert-sink` (`node:20.18.0-alpine3.20`)| `8080` | `monitoring` | Microservice chuyên biệt tiếp nhận webhook cảnh báo sự cố từ Grafana Alerting và ghi nhật ký kiểm toán. Chạy dưới quyền `node` (UID 1000). |

---

## BẢNG THỐNG KÊ SỐ LIỆU THỰC TẾ TRONG KHO MÃ NGUỒN (GIT METRICS)

| Commit | Mã băm (Hash) | Thông điệp Commit chuẩn | Số tệp thay đổi | Số dòng thêm (+) / xóa (-) |
|:---:|:---:|---|:---:|:---:|
| **COMMIT 1** | `3e73d60` | `feat: Khởi tạo ứng dụng web đặt phòng khách sạn, CSDL PostgreSQL và Nginx Reverse Proxy với HTTPS` | **44 files** | +3450 dòng |
| **COMMIT 2** | `e115f3a` | `feat: Tích hợp hệ thống giám sát Prometheus và Grafana cùng các Exporter` | **14 files** | +1131 dòng / -154 dòng |
| **COMMIT 3** | `c6e97f7` | `feat: Thêm log tập trung Loki/Promtail và áp dụng các biện pháp hardening bảo mật` | **22 files** | +1339 dòng / -57 dòng |

- **Tổng số container đang chạy**: Đủ 12/12 container Up (healthy).
- **Tổng số cổng public ra host**: Duy nhất 2 cổng web (`80`, `443`) và 1 cổng quản trị SSH (`22`).
- **Tình trạng bí mật trong kho Git**: 0 mật khẩu bị lộ (`git grep` hoàn toàn sạch).

---

## NỘI DUNG TỔNG HỢP THEO TỪNG CHƯƠNG BÁO CÁO

### CHƯƠNG 1: GIỚI THIỆU ĐỀ TÀI VÀ KIẾN TRÚC TỔNG THỂ

#### (a) Đoạn mô tả học thuật triển khai thực tế
Hệ thống Đặt phòng Khách sạn được xây dựng nhằm mô phỏng và giải quyết bài toán quản trị vận hành lưu trú trong thực tế. Kiến trúc phần mềm áp dụng mô hình phân lớp hiện đại (3-Tier Multi-Container Architecture) kết hợp phương pháp luận DevOps và nguyên lý An toàn Thông tin "Defense-in-Depth" (Phòng thủ theo chiều sâu). 

Hệ thống được đóng gói hoàn toàn dưới dạng các container Docker độc lập, tách biệt thành 3 phân vùng mạng:
- Vùng `frontend`: Đóng vai trò DMZ tiếp nhận yêu cầu từ người dùng internet qua cổng Reverse Proxy HTTPS.
- Vùng `backend`: Được cấu hình thuộc tính `internal: true`, cách ly hoàn toàn hệ quản trị CSDL PostgreSQL và tầng truy cập dữ liệu khỏi internet, triệt tiêu nguy cơ rò rỉ dữ liệu từ bên ngoài.
- Vùng `monitoring`: Khu vực dành riêng cho các thành phần giám sát số liệu, gom log và gửi cảnh báo tự động mà không làm ảnh hưởng đến hiệu năng của ứng dụng nghiệp vụ.

#### (b) Đường dẫn file cấu hình đưa vào báo cáo
- Sơ đồ kiến trúc Mermaid: `README.md` (Mục 2).
- Cấu hình phân vùng mạng Docker Compose: `docker-compose.yml` (khối `networks:` và khối khai báo `networks` của từng service).

#### (c) Tên file bằng chứng (Evidence)
- `evidence/buoc0-moitruong.txt`: Thông tin cấu hình phần cứng VM, OS Ubuntu 24.04 LTS, Docker Engine và Docker Compose.

#### (d) Danh sách ảnh cần chụp kèm lệnh
- Ảnh thông tin hệ điều hành và môi trường Docker:
  ```bash
  hostnamectl && docker --version && docker compose version
  ```

---

### CHƯƠNG 2: PHÁT TRIỂN ỨNG DỤNG WEB, CSDL POSTGRESQL VÀ NGINX REVERSE PROXY (COMMIT 1)

#### (a) Đoạn mô tả học thuật triển khai thực tế
Ứng dụng web được phát triển bằng nền tảng Node.js 20 và framework Express.js, sử dụng kỹ thuật Server-Side Rendering (SSR) với EJS template engine giúp tối ưu tốc độ phản hồi và bảo mật. Cơ sở dữ liệu quan hệ PostgreSQL 16 được thiết kế chuẩn hóa với 7 bảng nghiệp vụ liên kết chặt chẽ (`users`, `room_types`, `rooms`, `services`, `bookings`, `booking_services`, `payments`), hỗ trợ đầy đủ các ràng buộc toàn vẹn khóa ngoại và chỉ mục tìm kiếm.

Hệ thống phân quyền hỗ trợ 3 vai trò:
- Khách hàng (`customer`): Đặt phòng theo khoảng ngày, chống xung đột lịch phòng theo thời gian thực (Conflict Prevention Algorithm), quản lý lịch sử đặt phòng.
- Lễ tân (`staff`): Đặt phòng trực tiếp, xử lý Check-in chuyển đổi trạng thái phòng sang `occupied`, ghi nhận dịch vụ phát sinh, Check-out tính toán hóa đơn và nhận thanh toán (tiền mặt/thẻ/QR).
- Quản trị viên (`manager`): Theo dõi Dashboard KPI doanh thu & công suất buồng phòng, quản lý hạng phòng có upload ảnh an toàn (kiểm tra MIME type và giới hạn dung lượng).

Tầng Reverse Proxy Nginx được triển khai tại cổng 443 với giao thức HTTPS, sử dụng chứng chỉ SSL tự ký có đầy đủ Subject Alternative Name (SAN). Cổng 80 tự động chuyển hướng 301 sang HTTPS. Ngoài ra, Nginx đảm nhiệm định tuyến subpath an toàn cho công cụ pgAdmin tại `/pgadmin/`.

#### (b) Đường dẫn file cấu hình đưa vào báo cáo
- Khởi tạo bảng và dữ liệu CSDL: `db/init.sql`
- Cấu hình Reverse Proxy Nginx: `nginx/nginx.conf`
- Script sinh chứng chỉ SSL tự ký: `nginx/gen-cert.sh`
- Dockerfile ứng dụng web: `web/Dockerfile`
- Mã nguồn nghiệp vụ chính: `web/src/server.js`, `web/src/routes/`, `web/src/controllers/`

#### (c) Tên file bằng chứng (Evidence)
- `evidence/buoc12-web-db.txt`: Bằng chứng bảng CSDL, dữ liệu seed mẫu và API healthcheck.
- `evidence/buoc3-nginx.txt`: Bằng chứng chuyển hướng 301 từ HTTP sang HTTPS và proxy subpath pgAdmin.

#### (d) Danh sách ảnh cần chụp kèm lệnh
1. Giao diện trang chủ và danh sách phòng: `https://192.168.186.130/rooms`
2. Giao diện đặt phòng của khách hàng và lịch sử đặt phòng: `https://192.168.186.130/my-bookings`
3. Giao diện Check-in / Thêm dịch vụ / Thanh toán của lễ tân: `https://192.168.186.130/staff/bookings`
4. Giao diện Dashboard KPI doanh thu của Quản lý: `https://192.168.186.130/admin/dashboard`
5. Giao diện pgAdmin quản trị CSDL qua HTTPS: `https://192.168.186.130/pgadmin/`
6. Kiểm tra chuyển hướng 301 và chứng chỉ SSL bằng cURL:
   ```bash
   curl -I http://127.0.0.1/
   curl -kI https://127.0.0.1/
   ```

---

### CHƯƠNG 3: HỆ THỐNG GIÁM SÁT HIỆU NĂNG PROMETHEUS, EXPORTERS VÀ GRAFANA (COMMIT 2)

#### (a) Đoạn mô tả học thuật triển khai thực tế
Để đảm bảo khả năng quan sát (Observability) và giám sát hiệu năng theo thời gian thực, hệ thống tích hợp Prometheus v2.54.1 cùng 3 bộ trích xuất chỉ số (Exporters) chuyên dụng:
1. **Google cAdvisor (v0.49.1)**: Giám sát mức độ tiêu thụ CPU, bộ nhớ RAM, lưu lượng mạng và ổ đĩa của từng Docker container.
2. **Nginx Prometheus Exporter (v1.3.0)**: Kết nối tới endpoint nội bộ `http://nginx/nginx_status` để trích xuất số kết nối hoạt động (`active connections`), tần suất request/giây, và tỷ lệ kết nối chấp nhận/xử lý.
3. **PostgreSQL Exporter (v0.15.0)**: Sử dụng tài khoản phân quyền riêng biệt `exporter` với vai trò `pg_monitor` để thu thập số lượng kết nối đang mở, tần suất commit/rollback giao dịch, tỷ lệ đọc cache hit ratio và dung lượng CSDL.

Số liệu được trực quan hóa trên Grafana 11.2.0 thông qua cơ chế tự động nạp cấu hình (Provisioning) với 3 Dashboards chuyên nghiệp trong thư mục `Restaurant Monitoring`:
- `Restaurant - Containers`: Theo dõi mức tiêu thụ tài nguyên chi tiết của 12 container.
- `Restaurant - Nginx`: Trực quan hóa tải mạng của cổng Reverse Proxy.
- `Restaurant - PostgreSQL`: Trực quan hóa sức khỏe và hiệu năng CSDL quan hệ.
Hệ thống đã trải qua kịch bản sinh tải tự động (`scripts/gen_traffic.sh`) với 100 requests liên tiếp để xác nhận biểu đồ biến thiên số liệu trực quan và sống động.

#### (b) Đường dẫn file cấu hình đưa vào báo cáo
- Cấu hình Scrape Targets Prometheus: `prometheus/prometheus.yml`
- Cấu hình Datasource tự động Grafana: `grafana/provisioning/datasources/datasources.yaml`
- Cấu hình Dashboard Provider Grafana: `grafana/provisioning/dashboards/dashboards.yaml`
- Mã JSON Dashboards: `grafana/provisioning/dashboards/json/containers.json`, `nginx.json`, `postgres.json`
- Script sinh tải kiểm thử: `scripts/gen_traffic.sh`, `scripts/test_step4.sh`

#### (c) Tên file bằng chứng (Evidence)
- `evidence/buoc4-giamsat.txt`: Bằng chứng toàn diện gồm trạng thái 4 targets Prometheus UP, kết quả truy vấn PromQL thực tế, xác thực các cổng nội bộ không bị hở ra ngoài.

#### (d) Danh sách ảnh cần chụp kèm lệnh
1. Giao diện Prometheus Targets (hiển thị đủ 4 targets state UP): `http://localhost:9090/targets` (qua SSH tunnel `ssh -L 9090:localhost:9090 quachtuan@192.168.186.130`).
2. Dashboard "Restaurant - Containers" trên Grafana lúc có tải.
3. Dashboard "Restaurant - Nginx" trên Grafana lúc có tải.
4. Dashboard "Restaurant - PostgreSQL" trên Grafana lúc có tải.
5. Lệnh kiểm tra trạng thái targets từ terminal:
   ```bash
   docker exec hotel-prometheus wget -qO- http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
   ```

---

### CHƯƠNG 4: HỆ THỐNG THU THẬP LOG TẬP TRUNG LOKI, PROMTAIL VÀ CẢNH BÁO SỰ CỐ ALERTING (COMMIT 3)

#### (a) Đoạn mô tả học thuật triển khai thực tế
Để quản lý nhật ký tập trung và xử lý sự cố an toàn thông tin, giải pháp Grafana Loki 3.1.1 kết hợp cùng Promtail 3.1.1 đã được đưa vào vận hành:
- **Promtail**: Đóng vai trò Log Collector lắng nghe trực tiếp từ Docker container runtime socket, tự động phân loại stream log: `job="nginx"`, `job="webapp"`, `job="postgres"`. Nhãn `status` (mã HTTP) và `method` được bóc tách bằng regex pipeline stage để tăng tốc độ truy vấn mà vẫn tối ưu hóa độ cardinality.
- **Loki**: Lưu trữ và lập chỉ mục nhật ký dưới dạng các chuỗi (streams) nén hiệu năng cao.
- **Dashboard "Restaurant - Logs"**: Trực quan hóa phân bố log volume theo từng dịch vụ, biểu đồ thống kê các lần đăng nhập sai, và bảng truy vấn log stream theo thời gian thực.

**Quy tắc Cảnh báo An ninh (Grafana Alerting)**:
Đã thiết lập rule `Restaurant - Brute force login` áp dụng câu truy vấn LogQL:
```logql
sum(count_over_time({job="webapp"} |= "LOGIN_FAILED" [1m]))
```
Ngưỡng kích hoạt được đặt ở mức `> 5` lần đăng nhập sai trong 1 phút, đánh giá mỗi 10 giây trong khoảng thời gian kéo dài 30 giây (`for: 30s`).

**Thực nghiệm Sự cố và Phát hiện Tự động**:
Chạy kịch bản `scripts/simulate_bruteforce.sh` gửi 20 yêu cầu dò mật khẩu tài khoản `admin`. Khi số lượng sự cố vi phạm vượt ngưỡng, Grafana Alert chuyển sang trạng thái **Firing** và gửi webhook payload JSON tới microservice `hotel-alert-sink:8080`. Nhật ký `alert-sink` ghi nhận cảnh báo mức độ `critical`. Khi cuộc tấn công kết thúc, hệ thống tự động phục hồi về trạng thái **Resolved**.

Sau đó, đội ngũ kỹ thuật áp dụng giải pháp Rate Limiting trên Nginx (`limit_req_zone $binary_remote_addr zone=login_limit:10m rate=5r/m`). Chạy lại kịch bản kiểm thử: sau 2 request đầu, 18 request kế tiếp bị Nginx ngắt kết nối ngay từ cổng vào với mã **`HTTP 429 Too Many Requests`**, triệt tiêu hoàn toàn cuộc tấn công.

#### (b) Đường dẫn file cấu hình đưa vào báo cáo
- Cấu hình Loki Server: `loki/loki-config.yaml`
- Cấu hình Promtail Pipeline: `promtail/promtail-config.yaml`
- Cấu hình Alert Rule: `grafana/provisioning/alerting/rules.yaml`
- Cấu hình Contact Point & Policy: `grafana/provisioning/alerting/contact-points.yaml`, `notification-policies.yaml`
- Mã nguồn Alert Sink Service: `alert-sink/Dockerfile`, `alert-sink/server.js`
- Báo cáo điều tra sự cố: `docs/su-co-bruteforce.md`

#### (c) Tên file bằng chứng (Evidence)
- `evidence/buoc5-logql.txt`: Kết quả thực tế của 4 truy vấn LogQL từ Loki API.
- `evidence/buoc5-sucodo.txt`: Timeline toàn diện về sự cố Brute Force, webhook Firing và phản hồi HTTP 429.

#### (d) Danh sách ảnh cần chụp kèm lệnh
1. Explore Loki trên Grafana với câu truy vấn `{job="webapp"} |= "LOGIN_FAILED"`.
2. Dashboard "Restaurant - Logs" hiển thị đỉnh nhọn của cuộc tấn công Brute Force.
3. Trang Alert Rules trên Grafana ở trạng thái màu đỏ `Firing`.
4. Log terminal dịch vụ `hotel-alert-sink` nhận webhook:
   ```bash
   docker logs hotel-alert-sink --tail 15
   ```
5. Log terminal kịch bản Brute Force bị chặn đứng với mã HTTP 429:
   ```bash
   bash ~/hotel/scripts/simulate_bruteforce.sh
   ```

---

### CHƯƠNG 5: CÁC BIỆN PHÁP HARDENING BẢO MẬT HỆ THỐNG (COMMIT 3)

#### (a) Đoạn mô tả học thuật triển khai thực tế
Hệ thống được gia cố bảo mật toàn diện trên mọi lớp kiến trúc theo 8 tiêu chí kiểm tra bắt buộc:
1. **Non-root Container**: Các container ứng dụng nghiệp vụ và giám sát đều chạy dưới tài khoản người dùng không đặc quyền (`node` UID 1000, `nobody` UID 65534, `grafana` UID 472, `loki` UID 10001, `postgres` UID 70). Các trường hợp ngoại lệ sử dụng root (`nginx` master, `cadvisor`, `promtail`) đều được giới hạn quyền đọc `:ro` và drop capabilities.
2. **Network Isolation**: Tách 3 mạng Docker bridge độc lập. Mạng `backend` chứa PostgreSQL được gán cờ `internal: true`, ngăn chặn tuyệt đối lưu lượng trái phép từ bên ngoài và chặn kết nối ra internet từ CSDL.
3. **Cổng mở tối thiểu**: Chỉ Nginx mở cổng 80 và 443 ra máy chủ host. Toàn bộ các cổng dịch vụ nội bộ (5432, 3000, 9090, 3100, 8080, 9113, 9187) đều được đóng hoàn toàn trên host.
4. **Phân quyền tối thiểu CSDL (Least Privilege)**: Phân tách vai trò rõ ràng giữa superuser quản trị (`postgres`) và tài khoản ứng dụng (`hotel_app`). `hotel_app` chỉ có quyền `SELECT, INSERT, UPDATE, DELETE` trên các bảng nghiệp vụ. Lệnh `DROP TABLE` bị CSDL từ chối thực thi với thông báo `ERROR: must be owner of table users`.
5. **Cờ bảo mật Container & Giới hạn Tài nguyên**: Bật `no-new-privileges: true` chống leo thang đặc quyền; thu hồi toàn bộ quyền Linux qua `cap_drop: [ALL]`; thiết lập hạn mức CPU và RAM tối đa cho từng container.
6. **Hardening Nginx & Web App**: Bật `server_tokens off`, ẩn tiêu đề `X-Powered-By`, Cookie phiên bảo mật `HttpOnly; Secure; SameSite=Strict`, áp dụng đầy đủ các HTTP Security Headers (`HSTS`, `CSP`, `X-Frame-Options`,...).
7. **Tường lửa UFW**: Kích hoạt tường lửa hệ điều hành với chính sách mặc định chặn toàn bộ inbound (`default deny incoming`), chỉ mở đúng 3 cổng: `22/tcp`, `80/tcp`, `443/tcp`.
8. **Quét lỗ hổng Trivy**: Sử dụng Trivy v0.55.2 quét định kỳ toàn bộ 8 images; phân loại rủi ro HIGH/CRITICAL; hệ thống sử dụng base image tối giản Alpine 3.20 giúp giảm thiểu diện tích tấn công.
9. **Quản lý Bí mật (Secret Management)**: Tệp `.env` phân quyền `chmod 600`. Rà soát kho Git bằng `git grep` và `git log -p --all` xác nhận 100% không lộ mật khẩu.

#### (b) Đường dẫn file cấu hình đưa vào báo cáo
- Cấu hình Container Hardening & Networks: `docker-compose.yml`
- Cấu hình phân quyền CSDL: `db/init.sql`
- Cấu hình bảo mật Nginx: `nginx/nginx.conf`
- Cấu hình bảo mật Cookie & Headers: `web/src/server.js`

#### (c) Tên file bằng chứng (Evidence)
- `evidence/buoc6-hardening.txt`: Biên bản kiểm chứng chi tiết toàn bộ 8 tiêu chí hardening.
- `evidence/buoc6-trivy.txt`: Báo cáo quét lỗ hổng an ninh chi tiết từ Trivy.

#### (d) Danh sách ảnh cần chụp kèm lệnh
1. Kiểm tra tài khoản non-root:
   ```bash
   docker exec hotel-web id
   docker exec hotel-prometheus id
   ```
2. Kiểm tra cờ bảo mật container:
   ```bash
   docker inspect hotel-web --format 'SecurityOpt={{.HostConfig.SecurityOpt}} CapDrop={{.HostConfig.CapDrop}} Memory={{.HostConfig.Memory}}'
   ```
3. Kiểm tra phân quyền CSDL & lệnh DROP TABLE bị từ chối:
   ```bash
   docker exec hotel-db psql -U hotel_app -d hotel -c "SELECT COUNT(*) FROM rooms;"
   docker exec hotel-db psql -U hotel_app -d hotel -c "DROP TABLE users;"
   ```
4. Kiểm tra mạng cô lập backend:
   ```bash
   docker network ls | grep hotel
   docker network inspect hotel_backend | jq '.[0] | {Name: .Name, Internal: .Internal, Containers: [.Containers[] | .Name]}'
   ```
5. Kiểm tra bảo mật tệp `.env` và Git:
   ```bash
   ls -la ~/hotel/.env
   cd ~/hotel && git status
   ```
6. Kiểm tra HTTP Security Headers:
   ```bash
   curl -kI https://127.0.0.1/
   ```
7. Kiểm tra trạng thái tường lửa UFW:
   ```bash
   sudo ufw status verbose
   ```

---

### CHƯƠNG 6: KIỂM THỬ ĐÁNH GIÁ VÀ QUY TRÌNH KHÔI PHỤC TỪ TRẠNG THÁI SẠCH (COMMIT 3)

#### (a) Đoạn mô tả học thuật triển khai thực tế
Để chứng minh tính khả thi, độ tin cậy và khả năng triển khai tự động "bằng một lệnh duy nhất" (One-Click Deployment), quy trình kiểm thử từ trạng thái sạch (Clean State Verification) đã được tiến hành độc lập:
1. Sao lưu tệp cấu hình bí mật `.env` ra ngoài thư mục dự án.
2. Clone một bản sao mới hoàn toàn từ kho Git vào thư mục `~/hotel-verify`.
3. Sinh tệp `.env` mới từ `.env.example` với các mật khẩu ngẫu nhiên hoàn toàn mới.
4. Chạy script sinh chứng chỉ SSL tự ký `nginx/gen-cert.sh`.
5. Khởi động toàn bộ cụm dịch vụ bằng lệnh: `docker compose up -d --build`.
6. Thực thi bộ kiểm thử tự động (Smoke Test Suite):
   - Đăng nhập xác thực với các vai trò `admin`, `letan01`, `khach01`.
   - Tạo đơn đặt phòng mới, kiểm tra tính toán tổng tiền.
   - Làm thủ tục Check-in, thêm dịch vụ phụ trội, làm thủ tục Check-out và thanh toán.
   - Tải lên ảnh hạng phòng mới.
   - Xác thực 4 targets Prometheus đạt trạng thái `UP`.
   - Xác thực kết nối Loki và Grafana Dashboards.
   - Chạy kịch bản Brute Force xác nhận cơ chế cảnh báo Alerting hoạt động bình thường.
7. Toàn bộ 12/12 container đạt trạng thái `healthy`, chứng minh hệ thống có thể được tái tạo nhanh chóng trong môi trường khôi phục sau thảm họa (Disaster Recovery).

#### (b) Đường dẫn file cấu hình đưa vào báo cáo
- Tệp biến môi trường mẫu: `.env.example`
- Script kiểm thử tự động: `scripts/smoke_test_step6.py`

#### (c) Tên file bằng chứng (Evidence)
- `evidence/final-smoke-test.txt`: Nhật ký chi tiết kết quả chạy kiểm thử từ trạng thái sạch.

#### (d) Danh sách ảnh cần chụp kèm lệnh
1. Lệnh kiểm thử khôi phục từ trạng thái sạch:
   ```bash
   cat ~/hotel/evidence/final-smoke-test.txt
   ```
2. Xác nhận 12/12 container hoạt động ổn định:
   ```bash
   cd ~/hotel && docker compose ps
   ```

---

### KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN

#### 1. Kết luận Đạt được
- Đã xây dựng thành công ứng dụng web đặt phòng khách sạn hoàn chỉnh với đầy đủ các phân hệ nghiệp vụ theo vai trò.
- Đã thiết lập hạ tầng Docker Compose chuẩn mực với 12 microservices hoạt động bền bỉ, cô lập 3 vùng mạng an toàn.
- Đã tích hợp hệ thống giám sát metrics toàn diện với Prometheus, Grafana và 3 bộ Exporters chuyên dụng.
- Đã xây dựng hệ thống thu thập log tập trung với Grafana Loki & Promtail, tự động phát hiện và cảnh báo tấn công Brute Force theo thời gian thực.
- Đã áp dụng trọn vẹn 8 biện pháp Hardening an ninh nghiêm ngặt (non-root, network isolation, least privilege CSDL, drop capabilities, security headers, rate limiting, UFW firewall).
- Toàn bộ quy trình triển khai được duy trì nghiêm ngặt trong đúng 3 commit Git với lịch sử commit rõ ràng và không rò rỉ bất kỳ thông tin bí mật nào.

#### 2. Hướng phát triển Nâng cao trong Môi trường Sản xuất (Production)
- **Tích hợp WAF (Web Application Firewall)**: Triển khai ModSecurity hoặc Coraza WAF trên Nginx để ngăn chặn các cuộc tấn công OWASP Top 10 (SQL Injection, XSS, RCE).
- **Phòng thủ tự động với Fail2ban / CrowdSec**: Tự động chặn các IP vi phạm ở cấp độ nhân hệ điều hành (`iptables` / `nftables`) khi phát hiện tần suất đăng nhập sai vượt ngưỡng.
- **Xác thực 2 yếu tố (MFA / TOTP)**: Bắt buộc xác thực Google Authenticator đối với các tài khoản quản trị viên và lễ tân.
- **Chuyển đổi lên Kubernetes (K8s)**: Sử dụng Helm Chart để quản lý triển khai, tự động co giãn tài nguyên (HPA) và lưu trữ bí mật tập trung bằng HashiCorp Vault.
