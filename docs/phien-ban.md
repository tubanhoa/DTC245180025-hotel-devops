# Bảng Thành phần và Phiên bản Cố định (Hotel Booking System)

| Thành phần | Image / Gói | Phiên bản (Tag cố định) | Mục đích sử dụng |
|---|---|---|---|
| **Reverse Proxy** | `nginx` | `nginx:1.27.1-alpine` | Reverse Proxy, SSL Termination, Security Headers, Redirect 301 |
| **Web App** | `node` | `node:20.18.0-alpine3.20` | Backend Express.js, SSR EJS, API |
| **Database** | `postgres` | `postgres:16.4-alpine3.20` | CSDL quan hệ chính |
| **DB Admin** | `dpage/pgadmin4` | `dpage/pgadmin4:8.11` | Quản trị CSDL trực quan dưới subpath /pgadmin/ |
