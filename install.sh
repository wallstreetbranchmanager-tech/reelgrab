#!/usr/bin/env bash
# ReelGrab — 1-Click Installer for NVIDIA DGX Spark (GB10 / ARM64, DGX OS)
# Builds and runs ReelGrab in its own Docker container. Idempotent & safe to re-run.
set -euo pipefail

C_HEAD='\033[1;38;5;209m'; C_OK='\033[0;32m'; C_WARN='\033[0;33m'; C_ERR='\033[0;31m'; C_DIM='\033[0;90m'; NC='\033[0m'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$SCRIPT_DIR"

echo -e "${C_HEAD}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║   R E E L G R A B  —  1-CLICK INSTALL                 ║"
echo "  ║   Cinematic listing walkthroughs · Docker · DGX Spark ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

step(){ echo -e "\n${C_HEAD}▸ $1${NC}"; }
ok(){ echo -e "  ${C_OK}✓${NC} $1"; }
warn(){ echo -e "  ${C_WARN}!${NC} $1"; }
die(){ echo -e "  ${C_ERR}✗ $1${NC}"; exit 1; }

# ── 1. Environment detection ────────────────────────────────
step "Checking environment"
ARCH="$(uname -m)"
ok "Architecture: ${ARCH}"
if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
  ok "ARM64 detected — DGX Spark / GB10 compatible"
else
  warn "Non-ARM host (${ARCH}) — image builds multi-arch, will still run"
fi
if command -v nvidia-smi &>/dev/null; then
  GPU="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo '')"
  [[ -n "$GPU" ]] && ok "GPU: ${GPU}" || warn "nvidia-smi present but no GPU reported"
else
  warn "No nvidia-smi — running CPU render mode (Ken Burns). Fine for the core product."
fi

# ── 2. Docker ───────────────────────────────────────────────
step "Checking Docker"
command -v docker &>/dev/null || die "Docker not found. DGX OS ships with it; otherwise install Docker Engine."
docker info &>/dev/null 2>&1 || die "Docker daemon not reachable. Try: sudo systemctl start docker  (or add your user to the docker group)."
ok "Docker is running"
if docker compose version &>/dev/null 2>&1; then COMPOSE="docker compose"
elif command -v docker-compose &>/dev/null; then COMPOSE="docker-compose"
else die "Docker Compose not found. Install the compose plugin."; fi
ok "Compose: ${COMPOSE}"

# ── 3. Config (.env) ────────────────────────────────────────
step "Preparing configuration"
if [[ ! -f .env ]]; then
  SALT="$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n' 2>/dev/null || date +%s%N | sha256sum | head -c 48)"
  PORT="${REELGRAB_PORT:-8000}"
  cat > .env <<ENV
# ReelGrab configuration — generated $(date -u +%Y-%m-%dT%H:%M:%SZ)
REELGRAB_PORT=${PORT}
# Salts the IP+fingerprint free-video gate. Keep this secret & stable.
REELGRAB_IP_SALT=${SALT}

# Render engine: 'kenburns' (CPU, default) or 'ltx' (GPU on the Spark)
ADVANCED_CAMERA_PROVIDER=kenburns
# LTX_PATH=/opt/ltx
# LTX_CKPT=/opt/ltx/ckpt
# LTX_HOST_PATH=/opt/LTX-Video

# Stripe (leave blank to run without billing; free video still works)
STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=
STRIPE_PRICE_PRO_MONTHLY=
STRIPE_PRICE_CREDITS_10=
STRIPE_PRICE_CREDITS_50=
ENV
  ok "Wrote .env with a fresh random IP salt"
else
  ok ".env already present — leaving it untouched"
fi
PORT="$(grep -E '^REELGRAB_PORT=' .env | cut -d= -f2 || echo 8000)"; PORT="${PORT:-8000}"

# ── 4. Build & launch ───────────────────────────────────────
step "Building the ReelGrab image (first build ~3–5 min)"
$COMPOSE build 2>&1 | sed 's/^/    /' || die "Build failed. Scroll up for the first error."
ok "Image built"

step "Starting the container"
$COMPOSE up -d || die "Failed to start container."
ok "Container up"

# ── 5. Health check ─────────────────────────────────────────
step "Waiting for ReelGrab to become healthy"
URL="http://localhost:${PORT}/api"
for i in $(seq 1 30); do
  if curl -fs "$URL" >/dev/null 2>&1; then ok "Healthy at ${URL}"; HEALTHY=1; break; fi
  sleep 2; printf "    ${C_DIM}…waiting (%s/30)${NC}\r" "$i"
done
echo ""
[[ "${HEALTHY:-0}" == "1" ]] || { warn "Not healthy yet. Check logs: ${COMPOSE} logs -f reelgrab"; }

# ── 6. Done ─────────────────────────────────────────────────
IPADDR="$(hostname -I 2>/dev/null | awk '{print $1}' || echo localhost)"
echo -e "\n${C_OK}══════════════════════════════════════════════════════${NC}"
echo -e "${C_OK}  REELGRAB IS LIVE${NC}"
echo -e "${C_OK}══════════════════════════════════════════════════════${NC}"
echo -e "  Local:    ${C_HEAD}http://localhost:${PORT}${NC}"
[[ -n "$IPADDR" && "$IPADDR" != "localhost" ]] && echo -e "  Network:  ${C_HEAD}http://${IPADDR}:${PORT}${NC}   (open from your phone/iPad on the same network)"
echo ""
echo -e "  ${C_DIM}Logs:${NC}     ${COMPOSE} logs -f reelgrab"
echo -e "  ${C_DIM}Stop:${NC}     ${COMPOSE} down"
echo -e "  ${C_DIM}Update:${NC}   git pull && ${COMPOSE} up -d --build"
echo ""
echo -e "  ${C_DIM}Billing:${NC}  add Stripe keys to .env, then '${COMPOSE} up -d' to apply."
echo -e "  ${C_DIM}GPU/LTX:${NC}  set ADVANCED_CAMERA_PROVIDER=ltx + LTX paths in .env and"
echo -e "            uncomment 'gpus: all' in docker-compose.yml."
echo ""
