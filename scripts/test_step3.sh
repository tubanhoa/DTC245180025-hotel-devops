#!/bin/bash
set -euo pipefail

OUT=~/hotel/evidence/buoc3-nginx.txt
VM_IP="192.168.186.130"
COOKIE_JAR=$(mktemp)

echo "================================================================================" > "$OUT"
echo "EVIDENCE BƯỚC 3: NGINX REVERSE PROXY + HTTPS TỰ KÝ + SECURITY HEADERS (COMMIT 1)" >> "$OUT"
echo "Thời gian ghi nhận: $(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$OUT"
echo "Sinh viên: Quách Anh Tuấn - DTC245180025" >> "$OUT"
echo "================================================================================" >> "$OUT"

echo -e "\n1. KIỂM TRA CẤU HÌNH NGINX (nginx -t):" >> "$OUT"
cd ~/hotel && docker compose exec nginx nginx -t >> "$OUT" 2>&1

echo -e "\n2. TRẠNG THÁI CÁC CONTAINER (docker compose ps):" >> "$OUT"
docker compose ps >> "$OUT"

echo -e "\n3. KIỂM TRA CHUYỂN HƯỚNG HTTP -> HTTPS (PORT 80 -> 301):" >> "$OUT"
curl -sI "http://$VM_IP" | head -n 8 >> "$OUT"

echo -e "\n4. KIỂM TRA HTTPS VÀ SECURITY HEADERS (PORT 443):" >> "$OUT"
curl -skI "https://$VM_IP" >> "$OUT"

echo -e "\n5. KIỂM TRA CHỨNG CHỈ SSL VÀ SAN (openssl s_client):" >> "$OUT"
openssl s_client -connect localhost:443 -servername "$VM_IP" </dev/null 2>/dev/null | openssl x509 -noout -subject -dates -ext subjectAltName >> "$OUT"

echo -e "\n6. KIỂM TRA CỔNG 3000 VÀ 5050 ĐÃ BỊ GỠ BỎ TỪ NGOÀI:" >> "$OUT"
echo "--- Thử kết nối cổng 3000 từ ngoài (kỳ vọng thất bại) ---" >> "$OUT"
curl --connect-timeout 2 -s "http://$VM_IP:3000" && echo "Cổng 3000 vẫn mở (LỖI)" >> "$OUT" || echo "Cổng 3000 đã được chặn/đóng hoàn toàn (ĐẠT)" >> "$OUT"

echo "--- Thử kết nối cổng 5050 từ ngoài (kỳ vọng thất bại) ---" >> "$OUT"
curl --connect-timeout 2 -s "http://$VM_IP:5050" && echo "Cổng 5050 vẫn mở (LỖI)" >> "$OUT" || echo "Cổng 5050 đã được chặn/đóng hoàn toàn (ĐẠT)" >> "$OUT"

echo -e "\n7. KIỂM TRA TRUY CẬP ĐƯỜNG DẪN CON /pgadmin/ QUA HTTPS:" >> "$OUT"
curl -skI "https://$VM_IP/pgadmin/" | head -n 6 >> "$OUT"

echo -e "\n8. KIỂM TRA ĐĂNG NHẬP QUA HTTPS (COOKIE SECURE):" >> "$OUT"
CSRF=$(curl -sk -c "$COOKIE_JAR" "https://$VM_IP/login" | grep -o 'name="_csrf" value="[^"]*"' | head -n 1 | cut -d'"' -f4)
LOGIN_RESP=$(curl -sk -i -b "$COOKIE_JAR" -c "$COOKIE_JAR" -X POST "https://$VM_IP/login" \
  -d "username=admin&password=nd-RG4Y91DUAAcMhE2QMmA&_csrf=$CSRF")
echo "Đăng nhập HTTPS trả về: $(echo "$LOGIN_RESP" | head -n 1)" >> "$OUT"
echo "Set-Cookie HTTPS:" >> "$OUT"
echo "$LOGIN_RESP" | grep -i "set-cookie" >> "$OUT"

echo -e "\n9. KIỂM TRA UPLOAD ẢNH QUA HTTPS:" >> "$OUT"
TMP_PNG=$(mktemp --suffix=.png)
python3 -c "import base64; open('$TMP_PNG', 'wb').write(base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='))"
CSRF=$(curl -sk -b "$COOKIE_JAR" "https://$VM_IP/manager/rooms" | grep -o 'name="_csrf" value="[^"]*"' | head -n 1 | cut -d'"' -f4)
UPLOAD_RESP=$(curl -sk -i -b "$COOKIE_JAR" -X POST "https://$VM_IP/manager/room-types" \
  -H "X-CSRF-Token: $CSRF" \
  -F "name=Royal Penthouse" -F "base_price=3500000" -F "capacity=4" \
  -F "image=@$TMP_PNG;type=image/png")
echo "Upload ảnh qua HTTPS chuyển hướng: $(echo "$UPLOAD_RESP" | grep -i 'Location:')" >> "$OUT"
rm -f "$TMP_PNG" "$COOKIE_JAR"

echo -e "\n10. KIỂM TRA NGINX ACCESS LOG ĐẦY ĐỦ THU ĐƯỢC:" >> "$OUT"
docker compose logs --tail=5 nginx >> "$OUT"

echo -e "\nHoàn thành kiểm tra Bước 3. Bằng chứng lưu tại $OUT"
cat "$OUT"
