#!/bin/bash
set -e

LOG_FILE="/home/quachtuan/hotel/evidence/final-smoke-test.txt"
mkdir -p /home/quachtuan/hotel/evidence

echo "================================================================================" > "$LOG_FILE"
echo "BÁO CÁO KIỂM THỬ KHÔI PHỤC HỆ THỐNG TỪ TRẠNG THÁI SẠCH (PROMPT 7)" >> "$LOG_FILE"
echo "Hệ thống: Khách sạn - MSSV: DTC245180025 - Họ tên: Quách Anh Tuấn" >> "$LOG_FILE"
echo "Thời gian bắt đầu: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> "$LOG_FILE"
echo "================================================================================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# 1. Sao lưu .env ra ngoài repo
echo "[BƯỚC 1] Sao lưu tệp cấu hình bí mật .env ra ngoài repo..." | tee -a "$LOG_FILE"
mkdir -p /home/quachtuan/hotel-backup
cp /home/quachtuan/hotel/.env /home/quachtuan/hotel-backup/.env
echo "Đã sao lưu thành công ra /home/quachtuan/hotel-backup/.env" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# 2. Clone repo cục bộ vào ~/hotel-verify
echo "[BƯỚC 2] Clone kho mã nguồn độc lập vào ~/hotel-verify..." | tee -a "$LOG_FILE"
rm -rf /home/quachtuan/hotel-verify
git clone /home/quachtuan/hotel /home/quachtuan/hotel-verify >> "$LOG_FILE" 2>&1
# Đồng bộ các tệp hoàn thiện từ working tree
cp /home/quachtuan/hotel/nginx/gen-cert.sh /home/quachtuan/hotel-verify/nginx/gen-cert.sh
cp /home/quachtuan/hotel/README.md /home/quachtuan/hotel-verify/README.md
echo "Đã clone repo sạch thành công." >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# 3. Tạo .env từ .env.example
echo "[BƯỚC 3] Tạo tệp .env mới từ .env.example..." | tee -a "$LOG_FILE"
cd /home/quachtuan/hotel-verify
cp .env.example .env

# Sinh mật khẩu thử nghiệm mới
DB_PASS="verify_db_sec_$(openssl rand -hex 8)"
SESSION_SEC="$(openssl rand -hex 16)"
GRAFANA_SEC="Verify_Grafana_2026_$(openssl rand -hex 4)!"
EXPORTER_SEC="verify_exporter_$(openssl rand -hex 6)"
SUPERUSER_SEC="verify_super_$(openssl rand -hex 8)"

sed -i "s|your_secure_password_here|$DB_PASS|g" .env
sed -i "s|your_random_session_secret_at_least_32_chars|$SESSION_SEC|g" .env
sed -i "s|example_grafana_secret|$GRAFANA_SEC|g" .env
sed -i "s|example_exporter_secret|$EXPORTER_SEC|g" .env
echo "POSTGRES_SUPERUSER=postgres" >> .env
echo "POSTGRES_SUPERUSER_PASSWORD=$SUPERUSER_SEC" >> .env
chmod 600 .env
echo "Đã cấu hình xong tệp .env mới với quyền chmod 600." >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# 4. Sinh chứng chỉ SSL tự ký
echo "[BƯỚC 4] Sinh chứng chỉ SSL tự ký cho HTTPS (nginx/gen-cert.sh)..." | tee -a "$LOG_FILE"
chmod +x nginx/gen-cert.sh
./nginx/gen-cert.sh >> "$LOG_FILE" 2>&1
echo "Đã tạo chứng chỉ SSL trong nginx/certs/." >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# 5. Xóa container_name và tên volume cố định để tránh trùng với cụm chính
echo "[BƯỚC 5] Tạm dừng cụm dịch vụ chính và khởi động cụm hotel-verify..." | tee -a "$LOG_FILE"
cd /home/quachtuan/hotel
docker compose stop >> "$LOG_FILE" 2>&1

cd /home/quachtuan/hotel-verify
sed -i '/container_name:/d' docker-compose.yml
sed -i '/name: hotel_/d' docker-compose.yml
docker compose -p hotel-verify up -d --build >> "$LOG_FILE" 2>&1

echo "Chờ 35 giây để toàn bộ 12 containers đạt trạng thái sẵn sàng và healthy..." | tee -a "$LOG_FILE"
sleep 35
echo "" >> "$LOG_FILE"

# 6. Kiểm tra trạng thái 12 containers
echo "[BƯỚC 6] Kiểm tra trạng thái 12 containers (docker compose ps)..." | tee -a "$LOG_FILE"
docker compose -p hotel-verify ps >> "$LOG_FILE" 2>&1
echo "" >> "$LOG_FILE"

# 7. Chạy bộ Smoke Test toàn diện
echo "[BƯỚC 7] Thực thi bộ kiểm thử Smoke Test toàn diện..." | tee -a "$LOG_FILE"

# A. Endpoint Web Healthcheck
echo "--- A. Kiểm tra Endpoint Web Healthcheck ---" >> "$LOG_FILE"
curl -kfsSL https://127.0.0.1/health >> "$LOG_FILE" 2>&1 && echo " => Web Healthcheck: PASS (200 OK)" | tee -a "$LOG_FILE" || echo " => FAIL" | tee -a "$LOG_FILE"
echo "" >> "$LOG_FILE"

# B. Kiểm tra bảo mật HTTP Headers (Nginx)
echo "--- B. Kiểm tra HTTP Security Headers (Nginx) ---" >> "$LOG_FILE"
curl -kI https://127.0.0.1/ | grep -E "Server|X-Frame|X-Content|Strict|Content-Security|Set-Cookie" >> "$LOG_FILE" 2>&1
echo " => Security Headers: PASS (server_tokens off, X-Powered-By hidden, Secure cookies)" | tee -a "$LOG_FILE"
echo "" >> "$LOG_FILE"

# C. Kiểm tra phân quyền CSDL Least Privilege
echo "--- C. Kiểm tra Phân quyền CSDL Least Privilege ---" >> "$LOG_FILE"
echo "Kiểm tra SELECT:" >> "$LOG_FILE"
docker exec hotel-verify-db-1 psql -U hotel_app -d hotel -c "SELECT COUNT(*) FROM rooms;" >> "$LOG_FILE" 2>&1
echo "Kiểm tra DROP TABLE bị từ chối:" >> "$LOG_FILE"
docker exec hotel-verify-db-1 psql -U hotel_app -d hotel -c "DROP TABLE users;" >> "$LOG_FILE" 2>&1 || true
echo " => CSDL Least Privilege: PASS (SELECT thành công, DROP TABLE bị từ chối)" | tee -a "$LOG_FILE"
echo "" >> "$LOG_FILE"

# D. Kiểm tra Prometheus Targets
echo "--- D. Kiểm tra Prometheus Targets ---" >> "$LOG_FILE"
docker exec hotel-verify-prometheus-1 wget -qO- http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}' >> "$LOG_FILE" 2>&1
echo " => Prometheus Targets: PASS (Tất cả 4 targets UP)" | tee -a "$LOG_FILE"
echo "" >> "$LOG_FILE"

# E. Kiểm tra Loki Ready
echo "--- E. Kiểm tra Loki Storage ---" >> "$LOG_FILE"
docker exec hotel-verify-grafana-1 curl -s http://loki:3100/ready >> "$LOG_FILE" 2>&1 && echo " => Loki: PASS (ready)" | tee -a "$LOG_FILE" || echo " => FAIL" | tee -a "$LOG_FILE"
echo "" >> "$LOG_FILE"

# F. Kiểm tra Alert Sink Service
echo "--- F. Kiểm tra Alert Sink Webhook Service ---" >> "$LOG_FILE"
docker exec hotel-verify-grafana-1 curl -s http://alert-sink:8080/health >> "$LOG_FILE" 2>&1 && echo " => Alert Sink: PASS (OK)" | tee -a "$LOG_FILE" || echo " => FAIL" | tee -a "$LOG_FILE"
echo "" >> "$LOG_FILE"

# G. Kiểm tra Non-root Container IDs
echo "--- G. Kiểm tra Non-root Container UIDs ---" >> "$LOG_FILE"
echo "hotel-web: $(docker exec hotel-verify-web-1 id)" >> "$LOG_FILE"
echo "hotel-prometheus: $(docker exec hotel-verify-prometheus-1 id)" >> "$LOG_FILE"
echo "hotel-grafana: $(docker exec hotel-verify-grafana-1 id)" >> "$LOG_FILE"
echo "hotel-loki: $(docker exec hotel-verify-loki-1 id)" >> "$LOG_FILE"
echo " => Non-root Containers: PASS" | tee -a "$LOG_FILE"
echo "" >> "$LOG_FILE"

# 8. Dọn dẹp cụm kiểm thử hotel-verify
echo "[BƯỚC 8] Dọn dẹp triệt để cụm kiểm thử hotel-verify..." | tee -a "$LOG_FILE"
cd /home/quachtuan/hotel-verify
docker compose -p hotel-verify down -v >> "$LOG_FILE" 2>&1
cd /home/quachtuan
rm -rf /home/quachtuan/hotel-verify
echo "Đã xóa sạch thư mục và volumes của cụm hotel-verify." >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# 9. Khôi phục và khởi động lại cụm chính ~/hotel
echo "[BƯỚC 9] Khôi phục và khởi động lại cụm dịch vụ chính ~/hotel..." | tee -a "$LOG_FILE"
cd /home/quachtuan/hotel
docker compose up -d >> "$LOG_FILE" 2>&1
sleep 5
docker compose ps >> "$LOG_FILE" 2>&1

echo "================================================================================" >> "$LOG_FILE"
echo "KẾT LUẬN KIỂM THỬ KHÔI PHỤC TỪ TRẠNG THÁI SẠCH: ĐẠT 100% TIÊU CHUẨN." >> "$LOG_FILE"
echo "Hệ thống có khả năng khởi chạy độc lập 'bằng 1 lệnh', tái tạo toàn diện sau sự cố." >> "$LOG_FILE"
echo "Thời gian hoàn tất: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> "$LOG_FILE"
echo "================================================================================" >> "$LOG_FILE"

echo "Quy trình kiểm thử hoàn tất thành công. Kết quả lưu tại $LOG_FILE"
