# ReelGrab — cinematic listing walkthroughs
# Multi-arch: builds native on x86_64 AND arm64/aarch64 (NVIDIA DGX Spark / GB10).
# python:3.12-slim is a multi-arch manifest, so `docker build` on the Spark
# automatically pulls the arm64 layer. No x86-only binaries are used.
FROM python:3.12-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    REELGRAB_UPLOAD_DIR=/data/uploads \
    REELGRAB_DB=/data/uploads/reelgrab.db \
    PORT=8000

# ffmpeg = the whole render engine; curl = healthcheck; poppler-utils = PDF detail parsing
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    curl \
    poppler-utils \
    fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY backend/requirements.txt /app/backend/requirements.txt
RUN pip install --no-cache-dir -r /app/backend/requirements.txt

COPY . /app

RUN chmod +x /app/scripts/*.sh /app/scripts/*.py /app/start.sh /app/install.sh 2>/dev/null || true \
    && mkdir -p /data/uploads

# Run as non-root
RUN useradd -m -u 10001 reel && chown -R reel:reel /app /data
USER reel

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -f http://localhost:8000/api || exit 1

CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
