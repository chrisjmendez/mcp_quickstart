#!/bin/bash

echo "🛑 Stopping LLaMA + MCP + FastAPI stack..."

# 1. Stop Docker containers
docker-compose down

# 2. Kill Ollama if running
if [ -f logs/ollama.pid ]; then
  kill "$(cat logs/ollama.pid)" && echo "🦙 Ollama stopped." || echo "⚠️ Ollama already stopped."
  rm logs/ollama.pid
fi

# 3. Kill FastAPI if running
if [ -f logs/fastapi.pid ]; then
  kill "$(cat logs/fastapi.pid)" && echo "⚡ FastAPI stopped." || echo "⚠️ FastAPI already stopped."
  rm logs/fastapi.pid
fi

echo "✅ All services stopped."
