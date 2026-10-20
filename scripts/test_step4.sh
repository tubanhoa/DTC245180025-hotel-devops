#!/bin/bash
set -e

EVIDENCE_FILE="$HOME/hotel/evidence/buoc4-giamsat.txt"
mkdir -p "$HOME/hotel/evidence"

echo "================================================================================" > "$EVIDENCE_FILE"
echo "EVIDENCE BƯỚC 4: GIÁM SÁT PROMETHEUS, GRAFANA VÀ CÁC EXPORTER (COMMIT 2)" >> "$EVIDENCE_FILE"
echo "Thời gian ghi nhận: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> "$EVIDENCE_FILE"
echo "Sinh viên: Quách Anh Tuấn - DTC245180025" >> "$EVIDENCE_FILE"
echo "================================================================================" >> "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

echo "1. TRẠNG THÁI TẤT CẢ CONTAINER (docker compose ps):" >> "$EVIDENCE_FILE"
cd "$HOME/hotel"
docker compose ps >> "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

echo "2. KIỂM TRA TARGETS TRÊN PROMETHEUS (/api/v1/targets):" >> "$EVIDENCE_FILE"
docker exec -i hotel-prometheus wget -qO- http://localhost:9090/api/v1/targets >> "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

echo "3. KIỂM TRA PROMQL TRUY VẤN container_memory_usage_bytes:" >> "$EVIDENCE_FILE"
docker exec -i hotel-prometheus wget -qO- 'http://localhost:9090/api/v1/query?query=container_memory_usage_bytes%7Bname%3D~%22hotel.*%22%7D' >> "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

echo "4. KIỂM TRA PROMQL TRUY VẤN nginx_connections_active:" >> "$EVIDENCE_FILE"
docker exec -i hotel-prometheus wget -qO- 'http://localhost:9090/api/v1/query?query=nginx_connections_active' >> "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

echo "5. KIỂM TRA PROMQL TRUY VẤN pg_stat_database_numbackends:" >> "$EVIDENCE_FILE"
docker exec -i hotel-prometheus wget -qO- 'http://localhost:9090/api/v1/query?query=pg_stat_database_numbackends%7Bdatname%3D%22hotel%22%7D' >> "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

echo "6. KIỂM TRA PROMQL TRUY VẤN nginx_http_requests_total (SỐ REQUEST SAU SINH TẢI):" >> "$EVIDENCE_FILE"
docker exec -i hotel-prometheus wget -qO- 'http://localhost:9090/api/v1/query?query=nginx_http_requests_total' >> "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

echo "7. KIỂM TRA GRAFANA LOGIN HTTP/HTTPS (200 OK):" >> "$EVIDENCE_FILE"
curl -skI https://127.0.0.1/grafana/login >> "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

echo "8. KIỂM TRA GRAFANA PROVISIONED DATASOURCE (API):" >> "$EVIDENCE_FILE"
curl -sk -u 'admin:gR4f4n4_S3cur3_2026!' https://127.0.0.1/grafana/api/datasources >> "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

echo "9. KIỂM TRA GRAFANA 3 DASHBOARDS TRONG THƯ MỤC 'Restaurant Monitoring' (API):" >> "$EVIDENCE_FILE"
curl -sk -u 'admin:gR4f4n4_S3cur3_2026!' https://127.0.0.1/grafana/api/search >> "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

echo "10. CÁC CỔNG NỘI BỘ KHÔNG BỊ EXPOSE RA NGOÀI (CHỈ 80, 443 QUA NGINX):" >> "$EVIDENCE_FILE"
for port in 9090 3000 8080 9113 9187; do
  nc -zv -w 2 127.0.0.1 $port 2>&1 | grep -q "succeeded" && echo "CẢNH BÁO: Cổng $port bị hở" >> "$EVIDENCE_FILE" || echo "Cổng $port đóng an toàn (không public ra ngoài) - ĐẠT" >> "$EVIDENCE_FILE"
done
echo "" >> "$EVIDENCE_FILE"

echo "=== GHI NHẬN EVIDENCE BƯỚC 4 HOÀN TẤT ==="
