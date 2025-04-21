#!/bin/bash

# Title for vibes
echo "🧠 Starting LLaMA + MCP + FastAPI stack..."

# 1. Start Docker MCP server
echo "🐳 Starting Docker (MCP server)..."
docker-compose up > logs/docker.log 2>&1 &

# 2. Start Ollama server
echo "🦙 Starting Ollama..."
ollama serve > logs/ollama.log 2>&1 &

# 3. Start FastAPI server with auto-reload
echo "⚡ Starting FastAPI server..."
uvicorn prompt_sql_runner:app --reload --port 8090 > logs/fastapi.log 2>&1 &

# Optional: wait a beat for ports to open
sleep 2

# 4. Confirm
echo "✅ All systems should be launching! Logs are in ./logs/"
