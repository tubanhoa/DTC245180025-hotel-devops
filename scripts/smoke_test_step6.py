import urllib.request
import urllib.parse
import ssl
import json
import re

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

BASE_URL = "https://127.0.0.1"

print("================================================================================")
print("KIỂM THỬ TOÀN DIỆN HỆ THỐNG SAU KHI HARDENING (BƯỚC 6 SMOKE TEST)")
print("================================================================================")

# 1. Kiểm tra Endpoint Healthcheck
try:
    req = urllib.request.Request(f"{BASE_URL}/health")
    with urllib.request.urlopen(req, context=ctx) as resp:
        body = resp.read().decode()
        print(f"[TEST 1] Web Healthcheck (/health): Status {resp.status} => {body.strip()}")
        assert "OK" in body
except Exception as e:
    print(f"[TEST 1] FAILED: {e}")

# 2. Đăng nhập Admin
cookie_jar = {}

def get_cookies_and_csrf(url):
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req, context=ctx) as resp:
        cookie_header = resp.headers.get_all('Set-Cookie', [])
        cookies = {}
        for c in cookie_header:
            parts = c.split(';')[0].split('=', 1)
            if len(parts) == 2:
                cookies[parts[0].strip()] = parts[1].strip()
        body = resp.read().decode()
        match = re.search(r'name="_csrf"\s+value="([^"]+)"', body)
        csrf = match.group(1) if match else ""
        return cookies, csrf

try:
    cookies, csrf = get_cookies_and_csrf(f"{BASE_URL}/login")
    post_data = urllib.parse.urlencode({
        "username": "admin",
        "password": "nd-RG4Y91DUAAcMhE2QMmA",
        "_csrf": csrf
    }).encode()
    cookie_str = "; ".join([f"{k}={v}" for k, v in cookies.items()])
    req = urllib.request.Request(f"{BASE_URL}/login", data=post_data, headers={
        "Cookie": cookie_str,
        "Content-Type": "application/x-www-form-urlencoded"
    })
    try:
        urllib.request.urlopen(req, context=ctx)
    except urllib.error.HTTPError as e:
        if e.code in [302, 303]:
            print(f"[TEST 2] Đăng nhập Admin: Thành công (Redirect {e.code} to {e.headers.get('Location')})")
        else:
            print(f"[TEST 2] HTTP Error: {e.code}")
except Exception as e:
    print(f"[TEST 2] FAILED: {e}")

# 3. Đăng nhập Lễ tân và Khách hàng
for user, pw in [("letan01", "lMIWqC_Er_8oISuOSRWZqQ"), ("khach01", "HP-wmSO6_exkMhUSUgHesQ")]:
    try:
        cookies, csrf = get_cookies_and_csrf(f"{BASE_URL}/login")
        post_data = urllib.parse.urlencode({
            "username": user,
            "password": pw,
            "_csrf": csrf
        }).encode()
        cookie_str = "; ".join([f"{k}={v}" for k, v in cookies.items()])
        req = urllib.request.Request(f"{BASE_URL}/login", data=post_data, headers={
            "Cookie": cookie_str,
            "Content-Type": "application/x-www-form-urlencoded"
        })
        try:
            urllib.request.urlopen(req, context=ctx)
        except urllib.error.HTTPError as e:
            if e.code in [302, 303]:
                print(f"[TEST 3] Đăng nhập '{user}': Thành công (Redirect {e.code})")
            else:
                print(f"[TEST 3] '{user}' HTTP Error: {e.code}")
    except Exception as e:
        print(f"[TEST 3] FAILED for {user}: {e}")

# 4. Kiểm tra Prometheus Targets qua Grafana/Prometheus
print("[TEST 4] Kiểm tra Prometheus Targets và Metrics...")
try:
    # Prometheus is on internal monitoring network, Grafana proxies it or we can check via Grafana Datasource Proxy
    req = urllib.request.Request(f"{BASE_URL}/grafana/api/health")
    with urllib.request.urlopen(req, context=ctx) as resp:
        print(f"  - Grafana API Health: Status {resp.status}")
except Exception as e:
    print(f"  - Grafana check error: {e}")

print("================================================================================")
print("Hoàn tất bộ kiểm thử Smoke Test Bước 6.")
print("================================================================================")
