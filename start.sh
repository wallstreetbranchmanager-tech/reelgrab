#!/usr/bin/env bash
# ReelGrab — run without Docker (venv fallback). For the Spark, prefer ./install.sh (Docker).
set -euo pipefail
cd "$(dirname "$0")"
[ -d venv ] && source venv/bin/activate || true
export PYTHONPATH="${PYTHONPATH:-}:$(pwd)"
export REELGRAB_UPLOAD_DIR="${REELGRAB_UPLOAD_DIR:-/tmp/reelgrab}"
export REELGRAB_DB="${REELGRAB_DB:-${REELGRAB_UPLOAD_DIR}/reelgrab.db}"
export REELGRAB_IP_SALT="${REELGRAB_IP_SALT:-change-me}"
mkdir -p "$REELGRAB_UPLOAD_DIR"
echo "=============================================="
echo "  ReelGrab v2.0  ->  http://0.0.0.0:8000"
echo "  Manual upload · clean output · free first video"
echo "=============================================="
exec uvicorn backend.main:app --host 0.0.0.0 --port 8000 --workers 1
