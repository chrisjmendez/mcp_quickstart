#!/bin/bash

echo "🧠 Starting LLaMA + MCP + FastAPI stack..."

# Create logs directory if it doesn't exist
if [ ! -d "logs" ]; then
  echo "📁 Creating logs/ directory..."
  mkdir logs
  chmod 700 logs
fi

# Clean up old PIDs
rm -f logs/*.pid

# 1. Start Docker MCP server
echo "🐳 Starting Docker (MCP server)..."
docker-compose up -d > logs/docker.log 2>&1

# 2. Start Ollama server
echo "🦙 Starting Ollama..."
nohup ollama serve > logs/ollama.log 2>&1 &
echo $! > logs/ollama.pid

# 3. Start FastAPI server
echo "⚡ Starting FastAPI server..."
nohup uvicorn prompt_sql_runner:app --host 0.0.0.0 --port 8090 > logs/fastapi.log 2>&1 &
echo $! > logs/fastapi.pid

# Secure logs
chmod 600 logs/*.log

# Optional delay for startup
sleep 2

# 4. Confirm
echo "✅ All systems should be launching!"
echo "📄 Check logs in ./logs/"
