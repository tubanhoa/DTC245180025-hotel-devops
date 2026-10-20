# Hệ thống Đặt phòng Khách sạn (Hotel Booking System)

- **Sinh viên thực hiện**: Quách Anh Tuấn
- **Mã số sinh viên**: DTC245180025
- **Môn học**: Triển khai và Quản trị Hệ thống Phần mềm
- **Repository**: DTC245180025-hotel-devops

---

## 1. Giới thiệu Dự án
Hệ thống quản lý và đặt phòng khách sạn trực tuyến phục vụ 3 nhóm đối tượng:
- **Khách hàng (Customer)**: Xem danh sách phòng, lọc/tìm phòng trống theo ngày nhận - trả phòng, đặt phòng online chống trùng lịch, hủy đặt phòng.
- **Lễ tân (Staff)**: Đặt phòng trực tiếp (Walk-in), Check-in, ghi nhận dịch vụ phát sinh, Check-out & thanh toán, in hóa đơn, quản lý trạng thái dọn phòng.
- **Quản lý (Manager)**: Theo dõi Dashboard KPI doanh thu & công suất phòng, quản lý loại phòng kèm upload ảnh an toàn, quản lý danh mục phòng, dịch vụ và nhân sự.

---

## 2. Hướng dẫn Khởi chạy Hệ thống

### Bước 1: Chuẩn bị biến môi trường
Tạo file cấu hình bí mật `.env` từ file mẫu:
```bash
cp .env.example .env
# Chỉnh sửa mật khẩu bảo mật trong file .env nếu cần
chmod 600 .env
```

### Bước 2: Sinh chứng chỉ SSL tự ký cho HTTPS
Chạy script sinh chứng chỉ SSL tự ký có đầy đủ Subject Alternative Name (SAN):
```bash
chmod +x nginx/gen-cert.sh
./nginx/gen-cert.sh
```
Chứng chỉ `server.crt` và khóa bí mật `server.key` sẽ được tạo trong thư mục `nginx/certs/` (đã được cấu hình tự động loại trừ khỏi Git để đảm bảo bảo mật).

### Bước 3: Khởi động toàn bộ dịch vụ bằng Docker Compose
Khởi động toàn bộ hệ thống bằng MỘT lệnh duy nhất:
```bash
docker compose up -d --build
```

Kiểm tra trạng thái các dịch vụ:
```bash
docker compose ps
```

### Lưu ý quan trọng khi khởi động lại với Volume CSDL đã tồn tại
Khi khởi chạy hệ thống trên CSDL đã khởi tạo từ trước (Volume `hotel_db_data` đã tồn tại), script `db/init.sql` sẽ không chạy lại tự động. Để đảm bảo người dùng `exporter` phục vụ Prometheus có đầy đủ quyền giám sát `pg_monitor`, chạy lệnh sau:
```bash
docker exec -i hotel-db psql -U hotel_app -d hotel -c "DROP USER IF EXISTS exporter; CREATE USER exporter WITH PASSWORD 'p0stgr3s_3xp0rt3r_98234'; GRANT pg_monitor TO exporter;"
```

---

## 3. Bảng Địa chỉ Truy cập
- **Website Khách Sạn (HTTPS)**: `https://<VM_IP>/` (Cổng 80 tự động chuyển hướng 301 sang 443)
- **Công cụ Quản trị CSDL (pgAdmin)**: `https://<VM_IP>/pgadmin/`
- **Hệ thống Giám sát Hiệu năng (Grafana)**: `https://<VM_IP>/grafana/`
  - Đăng nhập: Tài khoản `admin`, mật khẩu cấu hình trong `.env` (`GRAFANA_ADMIN_PASSWORD`).
  - Đã nạp sẵn 3 Dashboards trong thư mục **Restaurant Monitoring**:
    1. `Restaurant - Containers`: Giám sát CPU %, RAM, Network I/O thời gian thực của các container.
    2. `Restaurant - Nginx`: Active connections, requests/sec, handled vs accepted connections.
    3. `Restaurant - PostgreSQL`: Kết nối CSDL, giao dịch/s (commit/rollback), cache hit ratio, kích thước CSDL.

### Cách xem Giao diện Prometheus Targets qua SSH Tunnel
Do Prometheus (`hotel-prometheus:9090`) được bảo mật an toàn trong mạng nội bộ Docker và không mở cổng ra ngoài, để truy cập giao diện Prometheus Web UI từ máy Windows (để chụp ảnh / kiểm tra):
1. Mở PowerShell hoặc Git Bash trên máy Windows:
   ```bash
   ssh -L 9090:localhost:9090 quachtuan@<VM_IP>
   ```
2. Mở trình duyệt trên máy Windows vào: `http://localhost:9090/targets`
