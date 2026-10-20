#!/bin/bash
set -euo pipefail

OUT=~/hotel/evidence/buoc12-web-db.txt
BASE_URL="http://localhost:3000"
COOKIE_JAR=$(mktemp)

echo "================================================================================" > "$OUT"
echo "EVIDENCE BƯỚC 1 & 2: ỨNG DỤNG WEB NODE.JS + POSTGRESQL + PGADMIN" >> "$OUT"
echo "Thời gian ghi nhận: $(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$OUT"
echo "Sinh viên: Quách Anh Tuấn - DTC245180025" >> "$OUT"
echo "================================================================================" >> "$OUT"

echo -e "\n1. TRẠNG THÁI CÁC CONTAINER (docker compose ps):" >> "$OUT"
cd ~/hotel && docker compose ps >> "$OUT"

echo -e "\n2. KIỂM TRA ENDPOINT /health VÀ TRANG ĐĂNG NHẬP:" >> "$OUT"
curl -s "$BASE_URL/health" >> "$OUT"
echo "" >> "$OUT"
curl -sI "$BASE_URL/login" | head -n 8 >> "$OUT"

echo -e "\n3. KIỂM TRA CSDL POSTGRESQL (7 BẢNG & SEED):" >> "$OUT"
docker compose exec db psql -U hotel_app -d hotel -c "\dt" >> "$OUT"
echo -e "\n--- Bảng users (Số lượng: $(docker compose exec db psql -U hotel_app -d hotel -t -c 'SELECT count(*) FROM users;')) ---" >> "$OUT"
docker compose exec db psql -U hotel_app -d hotel -c "SELECT id, username, email, full_name, role, is_active FROM users;" >> "$OUT"

echo -e "\n--- Bảng room_types ---" >> "$OUT"
docker compose exec db psql -U hotel_app -d hotel -c "SELECT id, name, base_price, capacity, image_path FROM room_types;" >> "$OUT"

echo -e "\n--- Bảng rooms (Số lượng: $(docker compose exec db psql -U hotel_app -d hotel -t -c 'SELECT count(*) FROM rooms;')) ---" >> "$OUT"
docker compose exec db psql -U hotel_app -d hotel -c "SELECT room_number, floor, status FROM rooms ORDER BY room_number ASC LIMIT 10;" >> "$OUT"

echo -e "\n--- Bảng services (Số lượng: $(docker compose exec db psql -U hotel_app -d hotel -t -c 'SELECT count(*) FROM services;')) ---" >> "$OUT"
docker compose exec db psql -U hotel_app -d hotel -c "SELECT id, name, price, is_available FROM services LIMIT 5;" >> "$OUT"

echo -e "\n4. KIỂM TRA ĐĂNG NHẬP THẤT BẠI VÀ ĐỊNH DẠNG LOGS (LOGIN_FAILED):" >> "$OUT"
# Lấy CSRF token trước
CSRF=$(curl -s -c "$COOKIE_JAR" "$BASE_URL/login" | grep -o 'name="_csrf" value="[^"]*"' | head -n 1 | cut -d'"' -f4)

# Test 1: Đăng nhập sai mật khẩu
echo "Gửi request đăng nhập sai mật khẩu..." >> "$OUT"
curl -s -b "$COOKIE_JAR" -c "$COOKIE_JAR" -d "username=admin&password=SaiMatKhau123&_csrf=$CSRF" "$BASE_URL/login" > /dev/null

# Test 2: Đăng nhập tài khoản không tồn tại
CSRF=$(curl -s -b "$COOKIE_JAR" "$BASE_URL/login" | grep -o 'name="_csrf" value="[^"]*"' | head -n 1 | cut -d'"' -f4)
echo "Gửi request đăng nhập user không tồn tại..." >> "$OUT"
curl -s -b "$COOKIE_JAR" -c "$COOKIE_JAR" -d "username=user_khong_ton_tai&password=any&_csrf=$CSRF" "$BASE_URL/login" > /dev/null

echo "--- Log web container ghi nhận sự kiện đăng nhập ---" >> "$OUT"
docker compose logs --tail=10 web | grep -E "LOGIN_FAILED|LOGIN_SUCCESS" >> "$OUT"

echo -e "\n5. KIỂM TRA END-TO-END FLOW (CURL + COOKIE JAR + CSRF):" >> "$OUT"

# 5.1 Khách hàng đăng ký tài khoản mới: test_khach03
echo "--- 5.1 Khách hàng đăng ký tài khoản mới (test_khach03) ---" >> "$OUT"
CSRF=$(curl -s -c "$COOKIE_JAR" "$BASE_URL/register" | grep -o 'name="_csrf" value="[^"]*"' | head -n 1 | cut -d'"' -f4)
REG_RESP=$(curl -s -i -b "$COOKIE_JAR" -c "$COOKIE_JAR" -X POST "$BASE_URL/register" \
  -d "username=test_khach03&email=test_khach03@test.com&password=Password123@&full_name=Nguyen Test&phone=0988776655&_csrf=$CSRF")
echo "Đăng ký trả về: $(echo "$REG_RESP" | head -n 1)" >> "$OUT"

# 5.2 Đăng nhập với tài khoản mới
echo "--- 5.2 Đăng nhập với tài khoản mới ---" >> "$OUT"
CSRF=$(curl -s -b "$COOKIE_JAR" -c "$COOKIE_JAR" "$BASE_URL/login" | grep -o 'name="_csrf" value="[^"]*"' | head -n 1 | cut -d'"' -f4)
LOGIN_RESP=$(curl -s -i -b "$COOKIE_JAR" -c "$COOKIE_JAR" -X POST "$BASE_URL/login" \
  -d "username=test_khach03&password=Password123@&_csrf=$CSRF")
echo "Đăng nhập trả về: $(echo "$LOGIN_RESP" | head -n 1)" >> "$OUT"

# 5.3 Tìm kiếm phòng trống (Lọc)
echo "--- 5.3 Tìm kiếm phòng trống ---" >> "$OUT"
ROOMS_SEARCH=$(curl -s -b "$COOKIE_JAR" "$BASE_URL/rooms?capacity=2&sort=price_asc")
echo "Trang tìm kiếm phòng trả về độ dài: $(echo "$ROOMS_SEARCH" | wc -c) bytes" >> "$OUT"

# 5.4 Đặt phòng: Vượt quá sức chứa -> Bị từ chối (400)
echo "--- 5.4 Thử đặt phòng vượt quá sức chứa (Standard 2 khách nhưng đặt 5 khách) ---" >> "$OUT"
CSRF=$(curl -s -b "$COOKIE_JAR" "$BASE_URL/rooms" | grep -o 'name="_csrf" value="[^"]*"' | head -n 1 | cut -d'"' -f4)
OVER_GUEST_RESP=$(curl -s -i -b "$COOKIE_JAR" -X POST "$BASE_URL/book" \
  -d "room_type_id=1&check_in_date=2026-11-01&check_out_date=2026-11-03&guests=5&note=DongNguoi&_csrf=$CSRF")
echo "Kết quả vượt sức chứa: $(echo "$OVER_GUEST_RESP" | head -n 1)" >> "$OUT"
echo "$OVER_GUEST_RESP" | grep -o "Vượt quá sức chứa" || true >> "$OUT"

# 5.5 Đặt phòng hợp lệ (Standard 2 khách, từ 2026-11-01 đến 2026-11-03)
echo "--- 5.5 Đặt phòng Standard hợp lệ ---" >> "$OUT"
CSRF=$(curl -s -b "$COOKIE_JAR" "$BASE_URL/rooms" | grep -o 'name="_csrf" value="[^"]*"' | head -n 1 | cut -d'"' -f4)
VALID_BOOK_RESP=$(curl -s -i -b "$COOKIE_JAR" -c "$COOKIE_JAR" -X POST "$BASE_URL/book" \
  -d "room_type_id=1&check_in_date=2026-11-01&check_out_date=2026-11-03&guests=2&note=HopLe&_csrf=$CSRF")
echo "Kết quả đặt phòng hợp lệ: $(echo "$VALID_BOOK_RESP" | head -n 1)" >> "$OUT"

# 5.6 Thử đặt trùng khoảng ngày khi hết phòng hoặc phòng đã kín lịch
echo "--- 5.6 Đặt phòng kiểm tra chống trùng lịch (Đến khi hết phòng trống) ---" >> "$OUT"
# Phòng loại 1 (Standard) có 3 phòng: 101, 102, 103. Đặt tiếp phòng 2 và 3 trong cùng khoảng ngày
CSRF=$(curl -s -b "$COOKIE_JAR" "$BASE_URL/rooms" | grep -o 'name="_csrf" value="[^"]*"' | head -n 1 | cut -d'"' -f4)
curl -s -b "$COOKIE_JAR" -X POST "$BASE_URL/book" -d "room_type_id=1&check_in_date=2026-11-01&check_out_date=2026-11-03&guests=2&_csrf=$CSRF" > /dev/null
CSRF=$(curl -s -b "$COOKIE_JAR" "$BASE_URL/rooms" | grep -o 'name="_csrf" value="[^"]*"' | head -n 1 | cut -d'"' -f4)
curl -s -b "$COOKIE_JAR" -X POST "$BASE_URL/book" -d "room_type_id=1&check_in_date=2026-11-01&check_out_date=2026-11-03&guests=2&_csrf=$CSRF" > /dev/null
# Đặt lần 4 -> Bị từ chối do hết phòng (409)
CSRF=$(curl -s -b "$COOKIE_JAR" "$BASE_URL/rooms" | grep -o 'name="_csrf" value="[^"]*"' | head -n 1 | cut -d'"' -f4)
FULL_RESP=$(curl -s -i -b "$COOKIE_JAR" -X POST "$BASE_URL/book" \
  -d "room_type_id=1&check_in_date=2026-11-01&check_out_date=2026-11-03&guests=2&_csrf=$CSRF")
echo "Kết quả khi phòng kín lịch trong khoảng ngày: $(echo "$FULL_RESP" | head -n 1)" >> "$OUT"
echo "$FULL_RESP" | grep -o "Hết phòng trống" || true >> "$OUT"

# 5.7 Customer truy cập trang /manager/dashboard -> Bị từ chối 403
echo "--- 5.7 Customer truy cập trái phép trang Quản lý (RBAC) ---" >> "$OUT"
FORBIDDEN_RESP=$(curl -s -i -b "$COOKIE_JAR" "$BASE_URL/manager/dashboard")
echo "Customer vào /manager/dashboard trả về: $(echo "$FORBIDDEN_RESP" | head -n 1)" >> "$OUT"

# 5.8 Staff đăng nhập (letan01) và xử lý lễ tân
echo "--- 5.8 Lễ tân (letan01) đăng nhập và thao tác nghiệp vụ ---" >> "$OUT"
STAFF_COOKIE=$(mktemp)
CSRF=$(curl -s -c "$STAFF_COOKIE" "$BASE_URL/login" | grep -o 'name="_csrf" value="[^"]*"' | head -n 1 | cut -d'"' -f4)
curl -s -b "$STAFF_COOKIE" -c "$STAFF_COOKIE" -X POST "$BASE_URL/login" \
  -d "username=letan01&password=lMIWqC_Er_8oISuOSRWZqQ&_csrf=$CSRF" > /dev/null

# Staff truy cập CRUD phòng -> Bị từ chối 403
STAFF_FORBIDDEN=$(curl -s -i -b "$STAFF_COOKIE" "$BASE_URL/manager/rooms")
echo "Staff vào /manager/rooms trả về: $(echo "$STAFF_FORBIDDEN" | head -n 1)" >> "$OUT"

# Lễ tân thêm dịch vụ vào đơn đặt phòng checked_in (BK-202610-002: id=2)
echo "--- 5.9 Lễ tân thêm dịch vụ vào phòng 201 (id=2) ---" >> "$OUT"
CSRF=$(curl -s -b "$STAFF_COOKIE" "$BASE_URL/reception" | grep -o 'name="_csrf" value="[^"]*"' | head -n 1 | cut -d'"' -f4)
ADD_SVC_RESP=$(curl -s -i -b "$STAFF_COOKIE" -X POST "$BASE_URL/reception/bookings/2/services" \
  -d "service_id=1&quantity=2&_csrf=$CSRF")
echo "Thêm dịch vụ trả về: $(echo "$ADD_SVC_RESP" | head -n 1)" >> "$OUT"

# Lễ tân Check-out và thanh toán cho phòng 201
echo "--- 5.10 Lễ tân Check-out và thanh toán cho phòng 201 ---" >> "$OUT"
CSRF=$(curl -s -b "$STAFF_COOKIE" "$BASE_URL/reception" | grep -o 'name="_csrf" value="[^"]*"' | head -n 1 | cut -d'"' -f4)
# Tổng tiền: phòng 1,600,000 + đưa đón sân bay 350,000 + 2 buffet sáng 300,000 = 2,250,000. Khách đưa 2,500,000. Tiền thối: 250,000.
CHECKOUT_RESP=$(curl -s -i -b "$STAFF_COOKIE" -X POST "$BASE_URL/reception/bookings/2/checkout" \
  -d "payment_method=cash&amount_paid=2500000&_csrf=$CSRF")
echo "Check-out trả về: $(echo "$CHECKOUT_RESP" | head -n 1)" >> "$OUT"

# Kiểm tra dữ liệu thanh toán trong CSDL
echo "--- Dữ liệu thanh toán trong CSDL (payments) ---" >> "$OUT"
docker compose exec db psql -U hotel_app -d hotel -c "SELECT booking_id, method, amount_due, amount_paid, change_amount, paid_at FROM payments WHERE booking_id = 2;" >> "$OUT"

# 5.11 Manager đăng nhập (admin) và kiểm tra Upload ảnh
echo "--- 5.11 Quản lý (admin) đăng nhập và kiểm tra Upload ảnh ---" >> "$OUT"
ADMIN_COOKIE=$(mktemp)
CSRF=$(curl -s -c "$ADMIN_COOKIE" "$BASE_URL/login" | grep -o 'name="_csrf" value="[^"]*"' | head -n 1 | cut -d'"' -f4)
curl -s -b "$ADMIN_COOKIE" -c "$ADMIN_COOKIE" -X POST "$BASE_URL/login" \
  -d "username=admin&password=nd-RG4Y91DUAAcMhE2QMmA&_csrf=$CSRF" > /dev/null

# Upload file .exe giả mạo -> Bị từ chối
echo "Thử upload file độc hại .exe..." >> "$OUT"
TMP_EXE=$(mktemp --suffix=.exe)
echo "FAKE_EXE_CONTENT" > "$TMP_EXE"
CSRF=$(curl -s -b "$ADMIN_COOKIE" "$BASE_URL/manager/rooms" | grep -o 'name="_csrf" value="[^"]*"' | head -n 1 | cut -d'"' -f4)
UPLOAD_EXE_RESP=$(curl -s -i -b "$ADMIN_COOKIE" -X POST "$BASE_URL/manager/room-types" \
  -F "name=TestExeRoom" -F "base_price=900000" -F "capacity=2" -F "_csrf=$CSRF" \
  -F "image=@$TMP_EXE;type=application/x-msdownload")
echo "Upload .exe trả về chuyển hướng thông báo lỗi: $(echo "$UPLOAD_EXE_RESP" | grep -i 'Location:')" >> "$OUT"
rm -f "$TMP_EXE"

# Upload ảnh PNG thật hợp lệ
echo "Upload ảnh PNG thật hợp lệ..." >> "$OUT"
TMP_PNG=$(mktemp --suffix=.png)
# Tạo file PNG 1x1 pixel hợp lệ bằng python
python3 -c "import base64; open('$TMP_PNG', 'wb').write(base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='))"
CSRF=$(curl -s -b "$ADMIN_COOKIE" "$BASE_URL/manager/rooms" | grep -o 'name="_csrf" value="[^"]*"' | head -n 1 | cut -d'"' -f4)
UPLOAD_PNG_RESP=$(curl -s -i -b "$ADMIN_COOKIE" -X POST "$BASE_URL/manager/room-types" \
  -F "name=Boutique Deluxe" -F "base_price=1500000" -F "capacity=2" -F "_csrf=$CSRF" \
  -F "image=@$TMP_PNG;type=image/png")
echo "Upload PNG hợp lệ trả về: $(echo "$UPLOAD_PNG_RESP" | grep -i 'Location:')" >> "$OUT"
rm -f "$TMP_PNG"

echo -e "\n6. KIỂM TRA PGADMIN (CỔNG 5050):" >> "$OUT"
curl -sI "http://localhost:5050/" | head -n 5 >> "$OUT"

rm -f "$COOKIE_JAR" "$STAFF_COOKIE" "$ADMIN_COOKIE"
echo -e "\nKiểm tra hoàn tất. Bằng chứng được lưu tại: $OUT"
cat "$OUT"
