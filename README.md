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

---

## 3. Bảng Địa chỉ Truy cập
- **Website Khách Sạn (HTTPS)**: `https://<VM_IP>/` (Cổng 80 tự động chuyển hướng 301 sang 443)
- **Công cụ Quản trị CSDL (pgAdmin)**: `https://<VM_IP>/pgadmin/`
