# Bảng Thành phần và Phiên bản Cố định (Hotel Booking System)

| Thành phần | Image / Gói | Phiên bản (Tag cố định) | Mục đích sử dụng |
|---|---|---|---|
| **Reverse Proxy** | `nginx` | `nginx:1.27.1-alpine` | Reverse Proxy, SSL Termination, Security Headers, Redirect 301 |
| **Web App** | `node` | `node:20.18.0-alpine3.20` | Backend Express.js, SSR EJS, API |
| **Database** | `postgres` | `postgres:16.4-alpine3.20` | CSDL quan hệ chính |
| **DB Admin** | `dpage/pgadmin4` | `dpage/pgadmin4:8.11` | Quản trị CSDL trực quan dưới subpath /pgadmin/ |
| **Metrics Collector** | `prom/prometheus` | `prom/prometheus:v2.54.1` | Thu thập và lưu trữ time-series metrics |
| **Visualization** | `grafana/grafana` | `grafana/grafana:11.2.0` | Dashboard trực quan hóa hiệu năng hệ thống qua subpath /grafana/ |
| **Container Metrics** | `gcr.io/cadvisor/cadvisor` | `gcr.io/cadvisor/cadvisor:v0.49.1` | Giám sát CPU, RAM, Network I/O của Docker containers |
| **Nginx Exporter** | `nginx/nginx-prometheus-exporter` | `nginx/nginx-prometheus-exporter:1.3.0` | Thu thập thông số kết nối và request của Nginx từ stub_status |
| **PostgreSQL Exporter** | `prometheuscommunity/postgres-exporter` | `prometheuscommunity/postgres-exporter:v0.15.0` | Thu thập chỉ số giao dịch, kết nối, cache hit của PostgreSQL |
