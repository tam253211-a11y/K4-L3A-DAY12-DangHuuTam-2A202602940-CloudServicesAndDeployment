# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization (production-ready)
#
#   Stage 1 `builder`: cài dependency vào /install (được phép nặng, bị vứt đi)
#   Stage 2 `runtime`: chỉ copy kết quả + source, chạy bằng user thường
#
# Build:  docker build -t day12-agent:prod .
# Chạy:   docker run -e AGENT_API_KEY=... -e REDIS_URL=... -p 8000:8000 day12-agent:prod
# ═══════════════════════════════════════════════════════════════════

# ─── Stage 1: builder ──────────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

# Chỉ copy requirements trước → layer pip install được cache,
# sửa code không làm cài lại thư viện
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ─── Stage 2: runtime ──────────────────────────────────────────────
FROM python:3.11-slim AS runtime

# Không ghi .pyc, log ra stdout ngay (không bị giữ trong buffer)
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# User thường, không có quyền root
RUN useradd --create-home --uid 10001 appuser

WORKDIR /app

# Thư viện đã cài ở builder
COPY --from=builder /install /usr/local

# Source code copy SAU cùng — thay đổi thường xuyên nhất
COPY --chown=appuser:appuser app ./app
COPY --chown=appuser:appuser utils ./utils

USER appuser

EXPOSE 8000

# Gọi /health theo đúng cổng app đang nghe ($PORT trên cloud, 8000 ở máy)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["python", "-c", "import os, urllib.request; urllib.request.urlopen('http://127.0.0.1:%s/health' % os.environ.get('PORT', '8000'), timeout=4)"]

# `exec` để uvicorn thay thế shell thành PID 1 → nhận được SIGTERM (CP4)
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
