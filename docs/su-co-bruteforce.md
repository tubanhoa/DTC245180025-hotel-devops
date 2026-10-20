# BÁO CÁO XỬ LÝ SỰ CỐ AN NINH: TẤN CÔNG DÒ MẬT KHẨU (BRUTE FORCE) VÀO TRANG ĐĂNG NHẬP

- **Hệ thống**: Quản lý Đặt phòng Khách sạn (Hotel Booking Management System)
- **Sinh viên thực hiện**: Quách Anh Tuấn
- **Mã số sinh viên**: DTC245180025
- **Môi trường**: Ubuntu 24.04 LTS (IP: `192.168.186.130`) trên VMware Workstation
- **Thời gian diễn ra sự cố**: 20/10/2026 từ 13:21:00 UTC đến 13:25:30 UTC
- **Mức độ nghiêm trọng**: CRITICAL (Đe dọa an toàn tài khoản quản trị viên và tính toàn vẹn hệ thống)

---

## 1. Mô tả sự cố
Vào lúc 13:21:00 UTC ngày 20/10/2026, hệ thống giám sát an ninh ghi nhận các hoạt động bất thường nhắm vào giao diện đăng nhập quản trị hệ thống tại endpoint `POST https://127.0.0.1/login`.

Kẻ tấn công sử dụng script tự động để gửi liên tục 20 yêu cầu xác thực trong thời gian ngắn (~0.5 giây/lần), áp dụng kỹ thuật **Dictionary Attack (Tấn công từ điển)** nhằm dò tìm mật khẩu của tài khoản `admin` bằng danh sách các mật khẩu thông dụng (`123456`, `password`, `admin123`, `qwerty`, `letmein`,...).

---

## 2. Cơ chế phát hiện tự động
Sự cố được phát hiện tự động thông qua chuỗi giám sát tập trung **Promtail -> Loki -> Grafana Alerting**:
1. **Promtail**: Thu thập dòng log đăng nhập theo thời gian thực từ container ứng dụng web `hotel-web`.
2. **Loki**: Lập chỉ mục dòng log với nhãn `job="webapp"` và nội dung định dạng chuẩn:
   ```text
   LOGIN_FAILED ip=172.21.0.1 user=admin reason=wrong_password
   ```
3. **Grafana Alert Rule**: Quy tắc cảnh báo `brute-force-login-rule` được kích hoạt dựa trên biểu thức LogQL:
   ```logql
   sum(count_over_time({job="webapp"} |= "LOGIN_FAILED" [1m]))
   ```
   - **Ngưỡng kích hoạt**: Vượt quá 5 lần đăng nhập sai trong 1 phút (`> 5`).
   - **Thời gian đánh giá**: Mỗi 10 giây, kéo dài trong 30 giây (`for: 30s`).
4. **Phát cảnh báo (Firing)**: Lúc 13:21:15 UTC, giá trị đếm vượt ngưỡng (đạt 20 lần), cảnh báo chuyển sang trạng thái **Firing**.
5. **Thông báo Webhook**: Grafana Contact Point kích hoạt webhook gửi cảnh báo an ninh tới dịch vụ `hotel-alert-sink:8080`:
   ```json
   {
     "status": "firing",
     "rule": "Restaurant - Brute force login",
     "severity": "critical",
     "summary": "Phat hien tan cong do mat khau (Brute Force) vao trang dang nhap"
   }
   ```

---

## 3. Quá trình điều tra và truy vết (Forensics)
Đội ngũ DevOps tiến hành truy vấn sâu vào kho log tập trung Loki qua giao diện Grafana Explore và LogQL:

### A. Truy vấn các sự kiện đăng nhập thất bại
- **LogQL**: `{job="webapp"} |= "LOGIN_FAILED"`
- **Kết quả điều tra**:
  + **IP nguồn**: `172.21.0.1` (IP gateway mạng Docker bridge đại diện cho máy trạm thử nghiệm).
  + **Tài khoản mục tiêu**: `user=admin`.
  + **Số lần thử nghiệm**: 20 lần trong khoảng 13:21:00 - 13:21:12 UTC.
  + **Lý do**: `reason=wrong_password`.

### B. Đối soát với Nhật ký truy cập Nginx Reverse Proxy
- **LogQL**: `{job="nginx"} |~ "POST /login"`
- **Kết quả đối soát**:
  + Toàn bộ 20 request ban đầu đều trả về mã trạng thái HTTP `200 OK` (ứng dụng web nhận request và render lại trang đăng nhập với thông báo lỗi).
  + Kẻ tấn công có thể tiếp tục dò quét không giới hạn nếu không có cơ chế chặn tần suất (Rate Limiting).

---

## 4. Xử lý và Khắc phục sự cố (Mitigation)
Để ngăn chặn tấn công Brute Force mà không làm gián đoạn người dùng thông thường, giải pháp **Rate Limiting** được triển khai trực tiếp tại tầng Reverse Proxy Nginx.

### A. Cấu hình Nginx Rate Limiting
Bổ sung các chỉ thị bảo mật vào `nginx/nginx.conf`:
```nginx
http {
    ...
    # Tạo vùng nhớ login_limit (10MB lưu được ~160,000 địa chỉ IP)
    # Giới hạn mỗi IP chỉ được gửi tối đa 5 request / phút (rate=5r/m)
    limit_req_zone $binary_remote_addr zone=login_limit:10m rate=5r/m;
    
    # Trả về mã lỗi 429 (Too Many Requests) khi vượt ngưỡng
    limit_req_status 429;

    server {
        listen 443 ssl;
        ...
        # Áp dụng riêng cho trang đăng nhập /login
        location = /login {
            limit_req zone=login_limit burst=3 nodelay;
            proxy_pass http://web:3000;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
        }
        ...
    }
}
```
*Giải thích thông số:*
- `rate=5r/m`: Giới hạn tốc độ trung bình 5 yêu cầu/phút.
- `burst=3 nodelay`: Cho phép người dùng vô tình gõ nhầm tối đa 3 lần liên tiếp mà không bị trễ, từ lần thứ 4 trở đi vượt tốc độ sẽ bị từ chối ngay lập tức với mã HTTP 429.

---

## 5. Kết quả kiểm thử xác nhận sau khắc phục
Tiến hành chạy lại kịch bản Brute Force 20 lần thử để nghiệm thu hiệu quả giải pháp:

1. **Kết quả phản hồi trên Terminal**:
   ```text
   [13:24:56] Lần thử 1/20: User='admin' Pass='123456' => HTTP Status: 200
   [13:24:56] Lần thử 2/20: User='admin' Pass='password' => HTTP Status: 200
   [13:24:57] Lần thử 3/20: User='admin' Pass='admin123' => HTTP Status: 429
   [13:24:57] Lần thử 4/20: User='admin' Pass='qwerty' => HTTP Status: 429
   ...
   [13:25:06] Lần thử 20/20: User='admin' Pass='badpassword20' => HTTP Status: 429
   ```
2. **Hiệu quả bảo vệ**:
   - 18/20 yêu cầu tấn công bị Nginx ngắt kết nối ngay từ cổng vào với mã `429 Too Many Requests`.
   - Lưu lượng tấn công hoàn toàn không chạm tới tầng Node.js Web App và PostgreSQL, triệt tiêu nguy cơ quá tải tài nguyên và ngăn chặn hoàn toàn khả năng dò trúng mật khẩu.
3. **Phục hồi cảnh báo (Resolved)**:
   - Tần suất sự kiện vi phạm giảm về dưới ngưỡng cho phép.
   - Grafana Alerting tự động gửi thông báo `RESOLVED` tới `hotel-alert-sink` lúc 13:24:40 UTC:
     ```text
     [2026-10-20T13:24:40.030Z] ALERT_WEBHOOK_RECEIVED: STATUS=resolved RULE="Restaurant - Brute force login" SEVERITY=critical
     ```

---

## 6. Bài học kinh nghiệm & Đề xuất nâng cao
Để hoàn thiện hệ thống phòng thủ theo chiều sâu (Defense-in-Depth) trong môi trường sản xuất thực tế, các biện pháp sau được khuyến nghị:
1. **Triển khai Fail2ban / CrowdSec**: Tự động phân tích log Nginx và thêm địa chỉ IP vi phạm vào quy tắc cấm `iptables` / `nftables` ở cấp độ hệ điều hành máy chủ trong 1-24 giờ.
2. **Tích hợp CAPTCHA**: Tự động hiển thị Cloudflare Turnstile hoặc reCAPTCHA v3 sau 3 lần đăng nhập thất bại.
3. **Khóa tài khoản tạm thời (Account Lockout)**: Tạm khóa tài khoản người dùng trong 15 phút nếu nhập sai mật khẩu quá 5 lần liên tiếp.
4. **Xác thực 2 yếu tố (2FA / MFA)**: Bắt buộc xác thực TOTP (Google Authenticator) đối với tất cả các tài khoản quản trị viên.
5. **Tường lửa ứng dụng web (WAF)**: Bật module ModSecurity / Coraza trên Nginx để lọc các payload độc hại và dấu hiệu tấn công tự động.
