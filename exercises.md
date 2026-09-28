# Phiếu Phản Ánh — K4 Level 3A, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: viết câu trả lời ngay dưới mỗi câu hỏi.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Đặng Hữu Tâm  
> Mã học viên: 2A202602940

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Khi deploy lên Railway, lúc đầu mình chỉ đặt 4 biến và quên `AGENT_API_KEY`.
Nếu trong code để mặc định `"changeme"` thì app vẫn khởi động bình thường,
`/ask` nhận khóa `changeme` — một chuỗi ai cũng đoán được vì repo công khai.
Bất kỳ ai đọc repo đều gọi được API trên URL public và tiêu ngân sách LLM của
mình, còn mình thì không hề biết vì dashboard vẫn báo "Online". Không có mặc
định thì `Settings()` ném `ValidationError` ngay khi đọc cấu hình, lỗi hiện ra
lúc mình đang deploy và nhìn log, chứ không phải lúc nhận hóa đơn.

Mình cũng quan sát được một điểm: service vẫn "Online" khi thiếu khóa, vì
`/health` không đọc `Settings` — lỗi chỉ lộ ra khi gọi `/ask`. Muốn fail fast
thật sự thì nên gọi `get_settings()` ngay trong `lifespan` lúc khởi động.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

Một dòng log lấy từ Deploy Logs trên Railway khi mình test rate limit:

```json
{"event": "ask_completed", "level": "info", "timestamp": "2026-09-28T09:58:47.058133+00:00", "user_id": "sv-ratelimit", "tokens_in": 302, "tokens_out": 43, "cost_usd": 7.11e-05}
```

Hai việc làm được mà `print("đã trả lời xong")` không làm được:

1. **Lọc và tổng hợp theo trường.** Railway tự tách các khóa thành cột, nên mình
   lọc được `user_id = sv-ratelimit` rồi cộng `cost_usd` để biết user nào tiêu
   nhiều tiền nhất, hoặc đếm số `ask_completed` trong 5 phút để đo tải.
2. **Phát hiện xu hướng và đặt cảnh báo.** Nhìn các dòng liên tiếp mình thấy
   `tokens_in` tăng dần 302 → 347 → 392 vì history được gửi kèm mỗi lượt. Với
   log có cấu trúc có thể đặt cảnh báo kiểu "tokens_in > 5000" hoặc "tổng
   cost_usd trong ngày > 1 USD". Chuỗi tự do thì máy không đọc ra số để so sánh.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | chưa đo được — tải `python:3.11` (~1GB) liên tục bị đứt mạng |
| Multi-stage | 271 MB (nén: 63.9 MB) |

Ghi chú về số đo: mình build bản 1 stage hai lần nhưng đều không xong vì mạng
bị đứt khi tải image `python:3.11` (lần đầu chạy 71 phút rồi thất bại). Log
build cho thấy riêng ba layer nén lớn nhất của `python:3.11` đã là
236.4 MB + 67.8 MB + 49.4 MB ≈ 354 MB, tức gấp hơn 5 lần **toàn bộ** image
multi-stage khi nén (63.9 MB, cột CONTENT SIZE của `docker images`).

Giải thích: phần dung lượng chênh lệch đó là những gì?

Bản 1 stage dùng `python:3.11` đầy đủ (Debian kèm gcc, make, header C, git…)
và `COPY . .` nên kéo theo cả `tests/`, tài liệu `.md`, `grade.py`… vào image.
Bản multi-stage chỉ giữ lại ở stage cuối: `python:3.11-slim`, thư viện đã cài
sẵn ở stage `builder` (copy từ `/install`) và hai thư mục `app/`, `utils/`.

Phần chênh lệch chủ yếu là **bộ công cụ build và thư viện hệ thống** của image
Python đầy đủ — thứ chỉ cần lúc cài đặt, không cần lúc chạy. Thêm vào đó là
pip cache (bản multi-stage dùng `--no-cache-dir`) và file thừa trong build
context. Trên mạng của mình, tải image `python:3.11` đầy đủ chạy hơn một tiếng
vẫn chưa xong, trong khi bản slim build xong trong vài phút — image nhỏ còn
nghĩa là deploy và scale nhanh hơn.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

Mình thêm một dòng comment vào cuối `app/main.py` rồi build lại với
`--progress=plain`. Kết quả:

| Layer | Trạng thái |
|---|---|
| `[builder] WORKDIR /build` | CACHED |
| `[builder] COPY requirements.txt .` | CACHED |
| `[builder] RUN pip install ...` | CACHED |
| `[runtime] RUN useradd ... appuser` | CACHED |
| `[runtime] COPY --from=builder /install /usr/local` | CACHED |
| `[runtime] COPY app ./app` | **chạy lại** (0.1s) |
| `[runtime] COPY utils ./utils` | **chạy lại** (0.1s) |

Cả lần build lại chỉ mất khoảng 9 giây. Docker kiểm tra checksum từng layer;
`requirements.txt` không đổi nên layer `pip install` được dùng lại. Chỉ từ
layer `COPY app` trở đi mới bị hủy cache (vì `utils` đứng sau `app` nên cũng
chạy lại, nhưng chỉ là copy file).

Nếu đặt `COPY . .` trước `RUN pip install` (như Dockerfile gốc), sửa một ký tự
trong `main.py` cũng làm thay đổi layer `COPY . .`, kéo theo `pip install`
chạy lại từ đầu — tải và cài lại toàn bộ thư viện mỗi lần sửa code, mất vài
phút thay vì vài giây.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

Chuỗi sự kiện khi container chạy bằng root:

1. Code có lỗ hổng (ví dụ một thư viện bị lỗi cho phép thực thi lệnh từ xa)
   → kẻ tấn công chạy được lệnh shell trong container.
2. Process đó là **root (UID 0)** trong container, nên đọc/ghi được mọi file
   trong container, cài thêm công cụ, sửa chính code của app.
3. UID 0 trong container cũng là UID 0 trên kernel của host (container dùng
   chung kernel). Chỉ cần thêm một cấu hình sai — mount volume từ host,
   mount `docker.sock`, chạy `--privileged` — hoặc một lỗ hổng kernel, là
   kẻ tấn công ghi được file của host với quyền root, tức là chiếm máy host.

`USER appuser` (UID 10001) cắt chuỗi ở **bước 2**: lệnh của kẻ tấn công chạy
với quyền user thường, không sửa được file hệ thống, không cài được gói, và
nếu có thoát ra host thì cũng chỉ là một user không đặc quyền. Code trong image
của mình còn được `COPY --chown=appuser`, nên app chỉ có đúng quyền nó cần.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

Tối đa **20 request trong 2 giây**.

Với cách đếm theo phút đồng hồ, bộ đếm reset về 0 lúc giây 00. Người dùng gửi
10 request lúc 10:00:59 (hết quota phút 10:00), rồi đến 10:01:00 bộ đếm reset
và họ gửi tiếp 10 request lúc 10:01:01. Cả 20 request nằm trong khoảng 2 giây
mà mỗi "phút" vẫn chỉ có 10 — đúng luật nhưng gấp đôi tải thật.

Với sliding window, mỗi lần kiểm tra mình đếm các request trong 60 giây **tính
ngược từ lúc hiện tại** (`zremrangebyscore(key, 0, now - 60)` rồi `zcard`). Lúc
10:01:01 thì 10 request lúc 10:00:59 vẫn nằm trong cửa sổ, nên request thứ 11
bị 429. Khi test trên Railway, 15 request liên tiếp cho kết quả đúng
`200 × 10` rồi `429 × 5`.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

Rate limit giới hạn **số lượng request trong 60 giây** (chống spam, bảo vệ
server). Cost guard giới hạn **số tiền mỗi user trong một tháng** (bảo vệ hóa
đơn). Một cái đếm theo thời gian ngắn, một cái cộng dồn tiền theo tháng.

- **Rate limit cho qua nhưng cost guard chặn:** một user chỉ gửi 5 request/phút
  (dưới hạn mức 10) nhưng mỗi câu hỏi rất dài và history đã đầy 20 tin nhắn.
  Mình thấy rõ điều này trong log: `tokens_in` tăng 302 → 347 → 392 qua từng
  lượt vì history được gửi kèm. Gửi đều như vậy suốt nhiều ngày, số request
  mỗi phút luôn hợp lệ nhưng tổng `cost_usd` vượt 10 USD → trả 402.
- **Cost guard cho qua nhưng rate limit chặn:** một script gửi 15 request
  "test" liên tiếp trong vài giây. Mỗi request chỉ tốn khoảng 0.00007 USD, ngân
  sách gần như còn nguyên, nhưng từ request thứ 11 đã bị 429 — đúng như khi
  mình test trên Railway.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

1. Redis mất kết nối. Cả 3 container cùng lúc gọi Redis trong health check và
   đều thất bại → cả 3 trả 503.
2. Orchestrator hiểu 503 ở liveness probe là "process hỏng", đợi đủ số lần
   thất bại (vài chục giây) rồi **restart cả 3 container** cùng lúc.
3. Trong lúc restart, không còn container nào nhận request → toàn bộ người dùng
   thấy lỗi 502/503, kể cả những request không cần Redis. Request đang xử lý
   dở cũng bị cắt.
4. Redis quay lại sau 30 giây, nhưng các container vẫn đang khởi động lại (có
   thể còn restart lặp nếu lúc khởi động Redis chưa kịp sẵn sàng).

Kết quả: một sự cố 30 giây ở Redis biến thành sự cố toàn hệ thống kéo dài hơn.

Khi tách hai endpoint, mình đã thử thật bằng `docker compose stop redis`:
`/health` vẫn **200**, `/ready` trả **503** `{"status":"not ready","redis":false}`.
Load balancer chỉ tạm ngừng gửi traffic vào, không restart gì cả. Bật Redis lại
là `/ready` tự về 200, không cần làm gì thêm.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

Compose của mình map cổng cố định `127.0.0.1:8000:8000`, nên `--scale agent=3`
bị trùng cổng (phải bỏ `ports` và thêm nginx làm load balancer). Mình kiểm
chứng tính stateless bằng cách khác: gọi `/ask` 3 lần với `X-User-Id: sv-demo`,
`history_length` là **0 → 2 → 4**; sau đó `docker compose restart agent` (process
mới hoàn toàn, RAM trống) rồi gọi tiếp, `history_length` là **6** — lịch sử
không mất vì nằm trong Redis, không nằm trong process.

Nếu lưu trong dict Python với 3 container sau load balancer (round-robin), mỗi
container có một dict riêng. Các lượt hỏi của cùng một user rơi lần lượt vào
A, B, C, nên `history_length` sẽ nhảy lung tung, ví dụ **0, 0, 0, 2, 2, 2, 4…**
thay vì tăng đều 0, 2, 4, 6. Agent "quên" câu trước một cách ngẫu nhiên, và
khi một container restart thì phần history của nó mất hẳn về 0.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

**Lỗi:** sau khi deploy lên Railway, `/health` và `/ready` đều 200, nhưng lệnh
kiểm tra `/ask` có API key (câu hỏi "Deploy là gì?") lại trả:

```
HTTP 400
{"detail":"There was an error parsing the body"}
```

**Tìm nguyên nhân:** 400 không phải 401 nên khóa đúng, và cùng lệnh đó với câu
hỏi `"test"` (chỉ ký tự ASCII) thì trả 200 — trong Deploy Logs thấy đủ 10 dòng
`200 OK` rồi `429`. Vậy lỗi nằm ở phần body chứa tiếng Việt: Git Bash trên
Windows truyền chuỗi `-d '{"question":"Deploy là gì?"}'` sang `curl` không phải
dạng UTF-8, FastAPI không parse được JSON nên trả 400.

**Sửa:** ghi body ra file JSON với encoding UTF-8 rồi gửi bằng
`--data-binary @body.json` kèm header `Content-Type: application/json; charset=utf-8`.
Lần này trả 200 với câu trả lời "Câu hỏi hay. Deploy là gì thường được giải
quyết bằng cách chuẩn hóa môi trường chạy…". Bài học: lỗi 4xx lúc test chưa
chắc do server — cần so sánh với một request đơn giản hơn để khoanh vùng.

Ngoài ra lúc deploy mình còn gặp: service báo "Online" dù chưa đặt
`AGENT_API_KEY` (phát hiện khi xem tab Variables chỉ có 4 biến), và `REDIS_URL`
ban đầu tham chiếu nhầm `${{day12-redis.DATABASE_URL}}`, sửa thành
`${{day12-redis.REDIS_URL}}` bằng gợi ý tự động của Railway.
