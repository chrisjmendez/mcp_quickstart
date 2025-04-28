#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

echo "🧠 Starting LLaMA + MCP + FastAPI stack…"

# Load .env
if [ ! -f .env ]; then
  echo "❌ .env file not found!"
  exit 1
fi
set -a; source .env; set +a

# Determine mode: use ENVIRONMENT if set, else localhost → dev, otherwise prod
if [ -n "${ENVIRONMENT-}" ]; then
  MODE="$ENVIRONMENT"
else
  case "$DOMAIN_URL" in
    localhost|127.*) MODE="development" ;;
    *)               MODE="production" ;;
  esac
fi
echo "🌐 Running in $MODE mode"

# Common: make logs dir
mkdir -p logs
chmod 700 logs

# Rotate logs (keep last 3)
for f in docker.log ollama.log fastapi.log; do
  [[ -f logs/$f.2 ]] && mv logs/$f.2 logs/$f.3
  [[ -f logs/$f.1 ]] && mv logs/$f.1 logs/$f.2
  [[ -f logs/$f   ]] && mv logs/$f   logs/$f.1
done
rm -f logs/*.pid

if [ "$MODE" = "development" ]; then
  echo "🚧 Development: skipping nginx & SSL"
  echo "📦 Bringing up MCP & API…"
  docker-compose up -d sqlite-mcp-server api-server >> logs/docker.log 2>&1
  echo "🔗 MCP:        http://localhost:8080/mcp"
  echo "🔗 FastAPI UI: http://localhost:8090"
  echo ""
  echo "✅ Dev stack is running!"
  exit 0
fi

# ——— production path ———
# validate needed env
if [ -z "${DOMAIN_URL-}" ] || [ -z "${DOMAIN_EMAIL-}" ]; then
  echo "❌ DOMAIN_URL and DOMAIN_EMAIL must be set in .env for production"
  exit 1
fi

# fix certbot permissions
sudo chown -R "$USER":"$USER" certbot || true
chmod -R u+rwX certbot || true

# helper: certificate expiry check
cert_expires_soon(){
  local cert="certbot/conf/live/${DOMAIN_URL}/fullchain.pem"
  if [ ! -f "$cert" ]; then return 0; fi
  local end=$(openssl x509 -enddate -noout -in "$cert" | cut -d= -f2)
  local end_ts=$(date -d "$end" +%s)
  local now_ts=$(date +%s)
  local days=$(( (end_ts - now_ts)/86400 ))
  (( days < 14 ))
}

echo "📦 Stage 1: HTTP-only bootstrap (for ACME)…"
docker-compose -f docker-compose.yml -f docker-compose.bootstrap.yml up -d \
  >> logs/docker.log 2>&1

sleep 5

if cert_expires_soon; then
  echo "🔐 Issuing/renewing cert for $DOMAIN_URL…"
  docker-compose -f docker-compose.yml -f docker-compose.bootstrap.yml run --rm certbot certonly \
    --webroot -w /var/www/certbot \
    --email "$DOMAIN_EMAIL" \
    --agree-tos \
    --no-eff-email \
    --expand \
    --cert-name "$DOMAIN_URL" \
    -d "$DOMAIN_URL" \
    >> logs/docker.log 2>&1
  echo "✅ Certificate issued"
else
  echo "✅ Certificate still valid, skipping issuance."
fi

echo "🧹 Shutting down bootstrap…"
docker-compose -f docker-compose.yml -f docker-compose.bootstrap.yml down \
  >> logs/docker.log 2>&1

# wait for cert to appear
echo "⏳ Waiting for certificate files…"
timeout=60
while [ ! -f "certbot/conf/live/${DOMAIN_URL}/fullchain.pem" ] && (( timeout > 0 )); do
  sleep 2; (( timeout-=2 ))
  echo "  …$timeout"
done
if (( timeout <= 0 )); then
  echo "❌ Certificate never appeared. Aborting."
  exit 1
fi

echo "🚀 Stage 2: Launching full HTTPS stack…"
docker-compose up -d >> logs/docker.log 2>&1

# Ollama & FastAPI on host
echo "🦙 Starting Ollama…"
nohup ollama serve > logs/ollama.log 2>&1 & echo $! > logs/ollama.pid

echo "⚡ Starting FastAPI…"
nohup uvicorn prompt_sql_runner:app --host 0.0.0.0 --port 8090 \
  > logs/fastapi.log 2>&1 & echo $! > logs/fastapi.pid

chmod 600 logs/*.log

echo ""
echo "✅ Production stack is up!"
echo "🔗 MCP:        https://$DOMAIN_URL/mcp"
echo "🔗 FastAPI UI: https://$DOMAIN_URL"
echo "📄 Logs:       ./logs/"