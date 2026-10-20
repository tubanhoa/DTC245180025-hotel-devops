#!/bin/bash
set -e

echo "=== BẮT ĐẦU SINH TẢI HỆ THỐNG (200 REQUESTS) ==="

for i in $(seq 1 200); do
  curl -sk https://127.0.0.1/rooms > /dev/null
  if [ $((i % 50)) -eq 0 ]; then
    echo "Đã gửi $i requests..."
  fi
done

echo "=== GỬI REQUESTS ĐĂNG NHẬP VÀ GIAO DỊCH DATABASE ==="
for user in admin letan01 khach01; do
  curl -sk -c /tmp/cookies.txt https://127.0.0.1/login > /tmp/login.html
  TOKEN=$(grep 'csrf-token' /tmp/login.html | sed -n 's/.*content="\([^"]*\)".*/\1/p' || true)
  if [ -n "$TOKEN" ]; then
    if [ "$user" = "admin" ]; then
      PASS="nd-RG4Y91DUAAcMhE2QMmA"
    elif [ "$user" = "letan01" ]; then
      PASS="lMIWqC_Er_8oISuOSRWZqQ"
    else
      PASS="HP-wmSO6_exkMhUSUgHesQ"
    fi
    curl -sk -b /tmp/cookies.txt -c /tmp/cookies.txt \
      -d "username=$user" \
      -d "password=$PASS" \
      -d "_csrf=$TOKEN" \
      https://127.0.0.1/login > /dev/null || true
    curl -sk -b /tmp/cookies.txt https://127.0.0.1/manager/dashboard > /dev/null || true
    curl -sk -b /tmp/cookies.txt https://127.0.0.1/reception > /dev/null || true
    curl -sk -b /tmp/cookies.txt https://127.0.0.1/my-bookings > /dev/null || true
  fi
  rm -f /tmp/cookies.txt /tmp/login.html
done

echo "=== HOÀN TẤT SINH TẢI THÀNH CÔNG ==="
