#!/bin/bash

echo "🧠 Starting LLaMA + MCP + FastAPI stack (Staged SSL)..."

# Load .env into environment
set -a
source .env
set +a

mkdir -p logs
chmod 700 logs

# 🔁 Rotate logs
for file in docker.log ollama.log fastapi.log; do
  [ -f logs/$file ] && mv logs/$file logs/$file.1
  [ -f logs/$file.1 ] && mv logs/$file.1 logs/$file.2
  [ -f logs/$file.2 ] && mv logs/$file.2 logs/$file.3
done

rm -f logs/*.pid

# 🥚 Stage 1: Bootstrap NGINX for Certbot
echo "📦 Stage 1: Starting bootstrap stack..."
docker-compose -f docker-compose.yml -f docker-compose.bootstrap.yml up -d > logs/docker.log 2>&1

# ⏳ Give NGINX time to boot
sleep 5

# 🌐 Load domain from .env
DOMAIN=$(grep DOMAIN_URL .env | cut -d '=' -f2)
EMAIL=$(grep DOMAIN_EMAIL .env | cut -d '=' -f2)

# 🔒 Run Certbot if needed or forced
if [ "$1" = "--force-cert" ] || [ ! -f "certbot/conf/live/${DOMAIN}/fullchain.pem" ]; then
  echo "🔐 Running Certbot for domain: $DOMAIN"
  docker-compose run --rm certbot certonly \
    --webroot -w /var/www/certbot \
    --email ${EMAIL} \
    --agree-tos \
    --no-eff-email \
    -d $DOMAIN >> logs/docker.log 2>&1
else
  echo "✅ Existing cert found. Skipping Certbot."
fi

# 🧹 Shut down bootstrap
echo "🧹 Cleaning up bootstrap containers..."
docker-compose -f docker-compose.yml -f docker-compose.bootstrap.yml down

# 🚀 Stage 2: Start full HTTPS stack
echo "🚀 Launching full HTTPS stack..."
docker-compose up -d >> logs/docker.log 2>&1

# 🦙 Start Ollama
echo "🦙 Starting Ollama..."
nohup ollama serve > logs/ollama.log 2>&1 &
echo $! > logs/ollama.pid

# ⚡ Start FastAPI
echo "⚡ Starting FastAPI server..."
nohup uvicorn prompt_sql_runner:app --host 0.0.0.0 --port 8090 > logs/fastapi.log 2>&1 &
echo $! > logs/fastapi.pid

chmod 600 logs/*.log

echo ""
echo "✅ All systems go!"
echo "🔗 MCP:        https://$DOMAIN/mcp"
echo "🔗 FastAPI UI: https://$DOMAIN"
echo "📄 Logs:       ./logs/"
