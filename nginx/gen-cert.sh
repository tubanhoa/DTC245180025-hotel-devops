#!/bin/bash
set -euo pipefail

CERT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/certs" && pwd)"
mkdir -p "$CERT_DIR"

VM_IP="192.168.186.130"

echo "=== Đang sinh chứng chỉ SSL tự ký cho Nginx (RSA 2048, 365 ngày) ==="
echo "IP máy ảo: $VM_IP"

CONFIG_FILE=$(mktemp)
cat << EOF > "$CONFIG_FILE"
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext
x509_extensions = req_ext

[dn]
C = VN
ST = Ho Chi Minh
L = Quan 1
O = Grand Hotel Resort
OU = IT DevOps
CN = $VM_IP

[req_ext]
subjectAltName = @alt_names

[alt_names]
IP.1 = $VM_IP
IP.2 = 127.0.0.1
DNS.1 = localhost
DNS.2 = hotel.local
EOF

openssl req -x509 -nodes -days 365 -newkey rsa:2048   -keyout "$CERT_DIR/server.key"   -out "$CERT_DIR/server.crt"   -config "$CONFIG_FILE"   -extensions req_ext

chmod 600 "$CERT_DIR/server.key"
chmod 644 "$CERT_DIR/server.crt"
rm -f "$CONFIG_FILE"

echo "Sinh chứng chỉ thành công:"
echo " - Key: $CERT_DIR/server.key"
echo " - Crt: $CERT_DIR/server.crt"
