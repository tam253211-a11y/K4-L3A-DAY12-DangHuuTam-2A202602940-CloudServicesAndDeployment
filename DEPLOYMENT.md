# Thông Tin Deploy — Checkpoint 5

> `pytest tests/test_cp5.py` đọc file này để tìm địa chỉ service và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, không ghi giá trị secret.**

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Đặng Hữu Tâm |
| Mã học viên | 2A202602940 |
| Repo | https://github.com/tam253211-a11y/K4-L3A-DAY12-DangHuuTam-2A202602940-CloudServicesAndDeployment |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://day12-agent-production-5964.up.railway.app |
| Platform | Railway (build từ `Dockerfile`, cấu hình `railway.toml`) |
| Ngày deploy | 2026-09-28 |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | Railway tự gán (8080), không tự đặt |
| `AGENT_API_KEY` | ✅ | khóa riêng cho cloud, đặt trong tab Variables của Railway, không nằm trong repo |
| `REDIS_URL` | ✅ | tham chiếu `${{day12-redis.REDIS_URL}}` tới service Redis của Railway (mạng nội bộ) |
| `RATE_LIMIT_PER_MINUTE` | ✅ | 10 |
| `MONTHLY_BUDGET_USD` | ✅ | 10.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

Thay `<URL>` bằng Public URL ở trên:

```bash
# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i <URL>/health

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i <URL>/ready

# 3. Không có API key — mong đợi 401
curl -i -X POST <URL>/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"Hello"}'

# 4. Có API key — mong đợi 200 kèm câu trả lời
curl -i -X POST <URL>/ask \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $AGENT_API_KEY" \
  -H "X-User-Id: sv-test" \
  -d '{"question":"Deploy là gì?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST <URL>/ask \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $AGENT_API_KEY" \
    -H "X-User-Id: sv-test" \
    -d '{"question":"test"}'
done; echo
```

## Kết Quả Chạy Thật

Chạy ngày 2026-09-28 vào `https://day12-agent-production-5964.up.railway.app`
(khóa API lấy từ biến môi trường, không in ra):

```
# 1. /health
HTTP/2 200
content-type: application/json
{"status":"ok","service":"day12-agent","version":"1.0.0"}

# 2. /ready
HTTP/2 200
{"status":"ready","redis":true}

# 3. /ask không có API key
HTTP/2 401
{"detail":"invalid or missing API key"}

# 4. /ask có API key (X-User-Id: sv-test)
HTTP 200
{"answer": "Câu hỏi hay. Deploy là gì thường được giải quyết bằng cách chuẩn hóa môi trường chạy: cùng một image chạy giống nhau ở laptop và trên cloud.", "user_id": "sv-test", "history_length": 0, "cost_usd": 2.145e-05, "tokens": {"in": 3, "out": 35}}

# 5. Rate limit — 15 lần liên tiếp, hạn mức 10/phút
200 200 200 200 200 200 200 200 200 200 429 429 429 429 429
```

Deploy log trên Railway xác nhận app đọc `$PORT` và uvicorn là PID 1 (nhận SIGTERM):

```
INFO:     Started server process [1]
{"event": "service_started", "level": "info", ..., "service": "day12-agent", "version": "1.0.0"}
INFO:     Uvicorn running on http://0.0.0.0:8080 (Press CTRL+C to quit)
INFO:     100.64.0.1:58855 - "GET /health HTTP/1.1" 200 OK
```

## Ảnh Chụp Màn Hình

Ảnh trong thư mục `screenshots/`:

- `screenshots/dashboard.png` — project Railway: `day12-agent` và `day12-redis` đều Online
- `screenshots/health.png` — kết quả gọi `/health` trên trình duyệt
- `screenshots/deploy-logs.png` — deploy log: uvicorn PID 1, cổng 8080 từ `$PORT`, `/health` 200
- `screenshots/rate-limit-logs.png` — log JSON `ask_completed`, 10 request 200 rồi 429
