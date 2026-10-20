#!/bin/sh
set -e

# Thiết lập mật khẩu cho user ứng dụng (hotel_app) và exporter từ biến môi trường
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    ALTER ROLE ${POSTGRES_APP_USER:-hotel_app} WITH PASSWORD '${POSTGRES_APP_PASSWORD}';
    ALTER ROLE exporter WITH PASSWORD '${EXPORTER_PASSWORD}';
EOSQL
