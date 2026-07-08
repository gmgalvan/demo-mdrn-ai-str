# --- Build stage: install dependencies into an isolated prefix ---
FROM python:3.12-slim AS builder

WORKDIR /build

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# --- Runtime stage: copy only what is needed to run the app ---
FROM python:3.12-slim

# Run as a non-root user for a slightly more realistic security posture
RUN useradd --create-home --shell /usr/sbin/nologin appuser

WORKDIR /srv/payment-api

COPY --from=builder /install /usr/local
COPY payments_api/ ./payments_api/

USER appuser

EXPOSE 8000

CMD ["uvicorn", "payments_api.main:app", "--host", "0.0.0.0", "--port", "8000"]
