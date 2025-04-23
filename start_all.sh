#!/bin/bash

echo "🧠 Starting LLaMA + MCP + FastAPI stack (Staged SSL)..."

# Load .env into environment safely
if [ ! -f .env ]; then
  echo "❌ .env file not found!"
  exit 1
fi
set -a
source .env
set +a

# Validate required env vars
if [ -z "$DOMAIN_URL" ] || [ -z "$DOMAIN_EMAIL" ]; then
  echo "❌ DOMAIN_URL and DOMAIN_EMAIL must be set in .env"
  exit 1
fi

# Init logs
mkdir -p logs
chmod 700 logs

# 🔁 Rotate logs (3 versions max)
for file in docker.log ollama.log fastapi.log; do
  [ -f logs/$file.2 ] && mv logs/$file.2 logs/$file.3
  [ -f logs/$file.1 ] && mv logs/$file.1 logs/$file.2
  [ -f logs/$file ] && mv logs/$file logs/$file.1
done

rm -f logs/*.pid

# 🥚 Stage 1: Bootstrap NGINX for Certbot
echo "📦 Stage 1: Starting bootstrap stack..."
if ! docker-compose -f docker-compose.yml -f docker-compose.bootstrap.yml up -d >> logs/docker.log 2>&1; then
  echo "❌ Failed to start bootstrap containers. See logs/docker.log"
  exit 1
fi

sleep 5  # Allow NGINX time to bind to port 80

# 🔒 Certbot run (only if cert doesn't exist or forced)
if [ "$1" = "--force-cert" ] || [ ! -f "certbot/conf/live/${DOMAIN_URL}/fullchain.pem" ]; then
  echo "🔐 Running Certbot for domain: $DOMAIN_URL"
  if ! docker-compose run --rm certbot certonly \
    --webroot -w /var/www/certbot \
    --email "$DOMAIN_EMAIL" \
    --agree-tos \
    --no-eff-email \
    -d "$DOMAIN_URL" >> logs/docker.log 2>&1; then
      echo "❌ Certbot failed. See logs/docker.log"
      exit 1
  fi
else
  echo "✅ Existing cert found. Skipping Certbot."
fi

# 🧹 Tear down bootstrap stack to free port 80
echo "🧹 Shutting down bootstrap containers..."
docker-compose -f docker-compose.yml -f docker-compose.bootstrap.yml down >> logs/docker.log 2>&1
sleep 3

# 🚀 Stage 2: Start full HTTPS stack
echo "🚀 Launching production stack..."
if ! docker-compose up -d >> logs/docker.log 2>&1; then
  echo "❌ Failed to start production containers. See logs/docker.log"
  exit 1
fi

# 🦙 Start Ollama
echo "🦙 Starting Ollama..."
nohup ollama serve > logs/ollama.log 2>&1 &
echo $! > logs/ollama.pid

# ⚡ Start FastAPI
echo "⚡ Starting FastAPI..."
nohup uvicorn prompt_sql_runner:app --host 0.0.0.0 --port 8090 > logs/fastapi.log 2>&1 &
echo $! > logs/fastapi.pid

chmod 600 logs/*.log

echo ""
echo "✅ All systems go!"
echo "🔗 MCP:        https://${DOMAIN_URL}/mcp"
echo "🔗 FastAPI UI: https://${DOMAIN_URL}"
echo "📄 Logs:       ./logs/"
