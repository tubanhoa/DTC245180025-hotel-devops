#!/bin/bash
# Kịch bản gửi 10 lần LOGIN_FAILED trực tiếp tới webapp để kích hoạt Firing phục vụ chụp ảnh
echo "Kích hoạt 10 sự kiện LOGIN_FAILED trực tiếp tại container webapp..."
for i in {1..10}; do
  docker exec hotel-web sh -c "echo 'LOGIN_FAILED ip=172.21.0.99 user=admin reason=wrong_password' >> /proc/1/fd/1"
done
echo "Đã gửi thành công 10 sự kiện. Promtail đẩy lên Loki và Grafana Alert sẽ chuyển sang FIRING trong ~15s."
