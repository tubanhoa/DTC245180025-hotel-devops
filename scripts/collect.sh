#!/bin/bash
set -euo pipefail

OUT="$HOME/hotel/evidence/buoc0-moitruong.txt"

{
  echo "================================================================================"
  echo "EVIDENCE BƯỚC 0: KHẢO SÁT MÔI TRƯỜNG VÀ CHUẨN BỊ REPO"
  echo "Thời gian ghi nhận: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
  echo "Sinh viên: Quách Anh Tuấn - DTC245180025"
  echo "================================================================================"

  echo ""
  echo "1. HỆ ĐIỀU HÀNH & TÀI NGUYÊN HỆ THỐNG:"
  echo "--- LSB Release ---"
  lsb_release -a 2>/dev/null || true

  echo ""
  echo "--- CPU ---"
  echo "$(nproc) cores - $(lscpu | grep 'Model name' | head -n 1)"

  echo ""
  echo "--- RAM ---"
  free -h

  echo ""
  echo "--- Ổ ĐĨA ---"
  df -h /

  echo ""
  echo "--- IP MÁY ẢO ---"
  ip -4 a show ens33

  echo ""
  echo "2. CÁC CỔNG ĐANG MỞ & XUNG ĐỘT TIỀM ẨN (ss -tlnp):"
  sudo ss -tlnp

  echo ""
  echo "3. DOCKER HIỆN CÓ TRÊN MÁY:"
  echo "--- docker ps -a ---"
  docker ps -a

  echo ""
  echo "--- docker network ls ---"
  docker network ls

  echo ""
  echo "--- docker volume ls ---"
  docker volume ls

  echo ""
  echo "4. PHIÊN BẢN CÔNG CỤ:"
  echo "- Docker: $(docker --version)"
  echo "- Docker Compose: $(docker compose version)"
  echo "- Git: $(git --version)"
  echo "- OpenSSL: $(openssl version)"
  echo "- Curl: $(curl --version | head -n 1)"
  echo "- UFW: $(sudo ufw status)"
  echo "- JQ: $(jq --version)"

  echo ""
  echo "5. KIỂM TRA PULL IMAGE MẠNG NGOÀI (alpine:3.20.0):"
  docker image inspect alpine:3.20.0 --format "RepoTags: {{.RepoTags}}, RepoDigests: {{.RepoDigests}}"

  echo ""
  echo "6. CẤU TRÚC THƯ MỤC DỰ ÁN (~/hotel):"
  tree ~/hotel -a -I .git

  echo ""
  echo "7. TRẠNG THÁI GIT:"
  cd ~/hotel && git status
} > "$OUT"

echo "Evidence written successfully to $OUT"
cat "$OUT"
