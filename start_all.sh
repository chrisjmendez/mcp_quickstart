#!/bin/bash

echo "🧠 Starting LLaMA + MCP + FastAPI stack..."

# Create logs dir if it doesn't exist
mkdir -p logs
chmod 700 logs

# Rotate old logs (keep last 3 versions)
for file in docker.log ollama.log fastapi.log; do
  if [ -f logs/$file ]; then
    mv logs/$file logs/$file.1
  fi
  if [ -f logs/$file.1 ]; then
    mv logs/$file.1 logs/$file.2
  fi
  if [ -f logs/$file.2 ]; then
    mv logs/$file.2 logs/$file.3
  fi
done

# Clean up stale PIDs
rm -f logs/*.pid

# 🐳 Start Docker MCP server
echo "🐳 Starting Docker (MCP server)..."
docker-compose up -d > logs/docker.log 2>&1

# 🦙 Start Ollama
echo "🦙 Starting Ollama..."
nohup ollama serve > logs/ollama.log 2>&1 &
echo $! > logs/ollama.pid

# ⚡ Start FastAPI
echo "⚡ Starting FastAPI server..."
nohup uvicorn prompt_sql_runner:app --host 0.0.0.0 --port 8090 > logs/fastapi.log 2>&1 &
echo $! > logs/fastapi.pid

chmod 600 logs/*.log

# Wait briefly
sleep 2

echo "✅ All systems should be launching!"
echo "📄 Check logs in ./logs/"
