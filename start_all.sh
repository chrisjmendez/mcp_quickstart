#!/bin/bash

echo "🧠 Starting LLaMA + MCP + FastAPI stack..."

# Create logs dir if it doesn't exist
mkdir -p logs
chmod 700 logs

# Rotate logs (keep last 3 versions)
for file in docker.log ollama.log fastapi.log; do
  [ -f logs/$file ] && mv logs/$file logs/$file.1
  [ -f logs/$file.1 ] && mv logs/$file.1 logs/$file.2
  [ -f logs/$file.2 ] && mv logs/$file.2 logs/$file.3
done

# Clean up stale PIDs
rm -f logs/*.pid

# 🐳 Start Docker MCP server
echo "🐳 Starting Docker (MCP server)..."
docker-compose up -d > logs/docker.log 2>&1
echo "🔗 MCP Server:     http://localhost:8080"

# 🦙 Start Ollama
echo "🦙 Starting Ollama..."
nohup ollama serve > logs/ollama.log 2>&1 &
echo $! > logs/ollama.pid
echo "🔗 Ollama Server:  http://localhost:11434"

# ⚡ Start FastAPI
echo "⚡ Starting FastAPI server..."
nohup uvicorn prompt_sql_runner:app --host 0.0.0.0 --port 8090 > logs/fastapi.log 2>&1 &
echo $! > logs/fastapi.pid
echo "🔗 FastAPI UI:     http://localhost:8090"

chmod 600 logs/*.log

# Wait a beat
sleep 2

echo -e "\n✅ All systems should be launching!"
echo "📄 Logs live in ./logs/"
