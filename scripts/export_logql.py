import urllib.request
import urllib.parse
import json
import datetime
import os

queries = [
    {
        "title": "TRUY VẤN 1: LỌC LOG NGINX MÃ TRẠNG THÁI LỖI HTTP 4XX / 5XX (ĐẶC BIỆT 429 TOO MANY REQUESTS)",
        "desc": "Truy vấn các dòng log từ Nginx có mã phản hồi HTTP 4xx hoặc 5xx (nhãn status được Promtail bóc tách tự động, ghi nhận các request bị chặn 429)",
        "logql": '{job="nginx", status=~"4[0-9]{2}|5[0-9]{2}"}'
    },
    {
        "title": "TRUY VẤN 2: LỌC LOG WEBAPP CHỨA TỪ KHÓA LỖI HOẶC NGOẠI LỆ (ERROR / EXCEPTION / FAILED)",
        "desc": "Truy vấn log từ ứng dụng web hotel-web chứa các từ khóa lỗi hoặc thất bại không phân biệt hoa thường",
        "logql": '{job="webapp"} |~ "(?i)(error|exception|failed)"'
    },
    {
        "title": "TRUY VẤN 3: LỌC CÁC SỰ KIỆN ĐĂNG NHẬP THẤT BẠI (LOGIN_FAILED)",
        "desc": "Truy vấn chính xác các sự kiện ghi nhận đăng nhập thất bại do tấn công dò mật khẩu (Brute Force)",
        "logql": '{job="webapp"} |= "LOGIN_FAILED"'
    },
    {
        "title": "TRUY VẤN 4: THỐNG KÊ TẦN SUẤT ĐĂNG NHẬP THẤT BẠI THEO THỜI GIAN (METRIC TỪ LOG)",
        "desc": "Tổng hợp số lượng sự kiện LOGIN_FAILED trong từng cửa sổ 1 phút để phục vụ quy tắc cảnh báo Grafana Alerting",
        "logql": 'sum(count_over_time({job="webapp"} |= "LOGIN_FAILED" [1m]))'
    }
]

os.makedirs('/home/quachtuan/hotel/evidence', exist_ok=True)
output_path = '/home/quachtuan/hotel/evidence/buoc5-logql.txt'

lines = []
now_str = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
lines.append("=" * 80)
lines.append("KẾT QUẢ TRUY VẤN LOGQL TẬP TRUNG TỪ LOKI (BƯỚC 5)")
lines.append("Hệ thống: Khách sạn - MSSV: DTC245180025 - Họ tên: Quách Anh Tuấn")
lines.append(f"Thời điểm trích xuất: {now_str}")
lines.append("=" * 80)
lines.append("")

for q in queries:
    lines.append("-" * 80)
    lines.append(f"[MỤC] {q['title']}")
    lines.append(f"Mô tả: {q['desc']}")
    lines.append(f"LogQL: {q['logql']}")
    lines.append("Kết quả từ Loki API:")
    lines.append("-" * 80)
    
    url = "http://127.0.0.1:3100/loki/api/v1/query_range?" + urllib.parse.urlencode({"query": q["logql"], "limit": 10})
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            result_type = data.get("data", {}).get("resultType", "")
            results = data.get("data", {}).get("result", [])
            
            if not results:
                lines.append("  (Không có dữ liệu trong khoảng thời gian truy vấn)")
            elif result_type == "streams":
                for item in results:
                    stream_labels = item.get("stream", {})
                    label_str = ", ".join([f'{k}="{v}"' for k, v in stream_labels.items()])
                    lines.append(f"  [STREAM: {{{label_str}}}]")
                    for val in item.get("values", []):
                        ts_ns = int(val[0])
                        ts_dt = datetime.datetime.fromtimestamp(ts_ns / 1e9, tz=datetime.timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
                        lines.append(f"    [{ts_dt} UTC] {val[1]}")
            elif result_type == "matrix":
                for item in results:
                    metric_labels = item.get("metric", {})
                    label_str = ", ".join([f'{k}="{v}"' for k, v in metric_labels.items()]) or "{}"
                    lines.append(f"  [METRIC: {label_str}]")
                    for val in item.get("values", []):
                        ts_s = float(val[0])
                        ts_dt = datetime.datetime.fromtimestamp(ts_s, tz=datetime.timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
                        lines.append(f"    [{ts_dt} UTC] Value = {val[1]}")
    except Exception as e:
        lines.append(f"  Lỗi khi truy vấn: {e}")
    lines.append("")

with open(output_path, "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")

print(f"Đã xuất dữ liệu thành công ra {output_path}")
