#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

echo "🛑 Stopping LLaMA + MCP + FastAPI stack…"

# 1) Bring down all compose services & orphans
docker-compose down --remove-orphans --volumes

# 2) Kill Ollama if launched locally
if [ -f logs/ollama.pid ]; then
  pid=$(< logs/ollama.pid)
  if kill "$pid" >/dev/null 2>&1; then
    echo "🦙 Ollama (PID $pid) stopped."
  else
    echo "⚠️ Ollama PID $pid not running."
  fi
  rm -f logs/ollama.pid
fi

# 3) Kill FastAPI if launched locally
if [ -f logs/fastapi.pid ]; then
  pid=$(< logs/fastapi.pid)
  if kill "$pid" >/dev/null 2>&1; then
    echo "⚡ FastAPI (PID $pid) stopped."
  else
    echo "⚠️ FastAPI PID $pid not running."
  fi
  rm -f logs/fastapi.pid
fi

echo "✅ All services stopped."