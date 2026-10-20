#!/bin/bash
set -euo pipefail

OUT=~/hotel/evidence/buoc0-moitruong.txt

echo "================================================================================" > "$OUT"
echo "EVIDENCE BƯỚC 0: KHẢO SÁT MÔI TRƯỜNG VÀ CHUẨN BỊ REPO" >> "$OUT"
echo "Thời gian ghi nhận: $(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$OUT"
echo "Sinh viên: Quách Anh Tuấn - DTC245180025" >> "$OUT"
echo "================================================================================" >> "$OUT"

echo -e "\n1. HỆ ĐIỀU HÀNH & TÀI NGUYÊN HỆ THỐNG:" >> "$OUT"
echo "--- LSB Release ---" >> "$OUT"
lsb_release -a 2>/dev/null >> "$OUT" || true

echo -e "\n--- CPU ---" >> "$OUT"
echo "$(nproc) cores - $(lscpu | grep Model name | head -n 1)" >> "$OUT"

echo -e "\n--- RAM ---" >> "$OUT"
free -h >> "$OUT"

echo -e "\n--- Ổ ĐĨA ---" >> "$OUT"
df -h / >> "$OUT"

echo -e "\n--- IP MÁY ẢO ---" >> "$OUT"
ip -4 a show ens33 >> "$OUT"

echo -e "\n2. CÁC CỔNG ĐANG MỞ & XUNG ĐỘT TIỀM ẨN (ss -tlnp):" >> "$OUT"
sudo ss -tlnp >> "$OUT"

echo -e "\n3. DOCKER HIỆN CÓ TRÊN MÁY:" >> "$OUT"
echo "--- docker ps -a ---" >> "$OUT"
docker ps -a >> "$OUT"

echo -e "\n--- docker network ls ---" >> "$OUT"
docker network ls >> "$OUT"

echo -e "\n--- docker volume ls ---" >> "$OUT"
docker volume ls >> "$OUT"

echo -e "\n4. PHIÊN BẢN CÔNG CỤ:" >> "$OUT"
echo "- Docker: $(docker --version)" >> "$OUT"
echo "- Docker Compose: $(docker compose version)" >> "$OUT"
echo "- Git: $(git --version)" >> "$OUT"
echo "- OpenSSL: $(openssl version)" >> "$OUT"
echo "- Curl: $(curl --version | head -n 1)" >> "$OUT"
echo "- UFW: $(sudo ufw status)" >> "$OUT"
echo "- JQ: $(jq --version)" >> "$OUT"

echo -e "\n5. KIỂM TRA PULL IMAGE MẠNG NGOÀI (alpine:3.20.0):" >> "$OUT"
docker image inspect alpine:3.20.0 --format "RepoTags: {{.RepoTags}}, Digest: {{.Digest}}" >> "$OUT"

echo -e "\n6. CẤU TRÚC THƯ MỤC DỰ ÁN (~/hotel):" >> "$OUT"
tree ~/hotel -a -I .git >> "$OUT"

echo -e "\n7. TRẠNG THÁI GIT:" >> "$OUT"
cd ~/hotel && git status >> "$OUT"

echo "Evidence written to $OUT"
EOF
chmod +x ~/hotel/scripts/collect_evidence_buoc0.sh
~/hotel/scripts/collect_evidence_buoc0.sh
cat ~/hotel/evidence/buoc0-moitruong.txt
