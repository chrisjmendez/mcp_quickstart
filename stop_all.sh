#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

echo "🛑 Stopping LLaMA + MCP + FastAPI stack…"

# 1. Stop all Docker containers (including FastAPI and MCP server if running in Docker)
docker-compose down --remove-orphans --volumes

# 2. Kill Ollama if running on host
pkill -f 'ollama serve' || true

# 3. Kill FastAPI (prompt_sql_runner:app) if running on host
pkill -f 'uvicorn prompt_sql_runner:app' || true

# 4. Kill MCP server (my_mcp_server:app) if running on host
pkill -f 'uvicorn my_mcp_server:app' || true

# 5. Optionally, clean up PID files
rm -f logs/*.pid

echo "✅ All services stopped."