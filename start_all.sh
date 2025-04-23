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

mkdir -p logs
chmod 700 logs

# Rotate logs (keep 3 versions)
for file in docker.log ollama.log fastapi.log; do
  [ -f logs/$file.2 ] && mv logs/$file.2 logs/$file.3
  [ -f logs/$file.1 ] && mv logs/$file.1 logs/$file.2
  [ -f logs/$file ] && mv logs/$file logs/$file.1
done

rm -f logs/*.pid

# Stage 1: Start bootstrap containers for HTTP-only NGINX
echo "📦 Stage 1: Starting bootstrap stack..."
if ! docker-compose -f docker-compose.yml -f docker-compose.bootstrap.yml up -d >> logs/docker.log 2>&1; then
  echo "❌ Failed to start bootstrap containers. See logs/docker.log"
  exit 1
fi

sleep 5  # Give NGINX time to bind to port 80

# Run Certbot (issue if missing, or --force-cert)
if [ "$1" = "--force-cert" ] || [ ! -f "certbot/conf/live/${DOMAIN_URL}/fullchain.pem" ]; then
  echo "🔐 Running Certbot for domain: $DOMAIN_URL"
  if ! docker-compose -f docker-compose.yml -f docker-compose.bootstrap.yml run --rm certbot certonly \
    --webroot -w /var/www/certbot \
    --email "$DOMAIN_EMAIL" \
    --agree-tos \
    --no-eff-email \
    --expand \
    --cert-name "$DOMAIN_URL" \
    -d "$DOMAIN_URL" >> logs/docker.log 2>&1; then
      echo "❌ Certbot failed. See logs/docker.log"
      exit 1
  fi
  echo "✅ Certbot successfully issued a certificate for $DOMAIN_URL"
else
  echo "✅ Existing cert found. Skipping Certbot."
fi

# 🛡 Fix permissions on cert files
echo "🔧 Fixing certbot permissions..."
sudo chown -R $USER:$USER certbot/conf

# Clean up bootstrap containers (free up port 80)
echo "🧹 Shutting down bootstrap containers..."
docker-compose -f docker-compose.yml -f docker-compose.bootstrap.yml down >> logs/docker.log 2>&1
sleep 3

# Add a safety timeout while waiting for the cert file
timeout=60
while [ ! -f "certbot/conf/live/${DOMAIN_URL}/fullchain.pem" ] && [ $timeout -gt 0 ]; do
  echo "⏳ Waiting for fullchain.pem... ($timeout s remaining)"
  sleep 2
  timeout=$((timeout - 2))
done

if [ $timeout -eq 0 ]; then
  echo "❌ Timeout waiting for certificate file. Aborting."
  exit 1
fi

# Stage 2: Launch production stack (with HTTPS)
echo "🚀 Launching production stack..."
if ! docker-compose up -d >> logs/docker.log 2>&1; then
  echo "❌ Failed to start production containers. See logs/docker.log"
  exit 1
fi

# Start Ollama
echo "🦙 Starting Ollama..."
nohup ollama serve > logs/ollama.log 2>&1 &
echo $! > logs/ollama.pid

# Start FastAPI
echo "⚡ Starting FastAPI..."
nohup uvicorn prompt_sql_runner:app --host 0.0.0.0 --port 8090 > logs/fastapi.log 2>&1 &
echo $! > logs/fastapi.pid

chmod 600 logs/*.log

echo ""
echo "✅ All systems go!"
echo "🔗 MCP:        https://${DOMAIN_URL}/mcp"
echo "🔗 FastAPI UI: https://${DOMAIN_URL}"
echo "📄 Logs:       ./logs/"
