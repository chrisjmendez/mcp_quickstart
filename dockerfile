FROM python:3.11-slim

# Install system deps
RUN apt-get update && apt-get install -y \
    sqlite3 \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set up working directory
WORKDIR /app

# Copy init SQL + setup script
COPY init_db.sh /app/init_db.sh
COPY requirements.txt /app/requirements.txt

# Python deps (if needed)
RUN pip install --no-cache-dir -r requirements.txt

# Init DB
RUN chmod +x init_db.sh && ./init_db.sh

# Start MCP server (replace with your actual start cmd)
CMD ["uvicorn", "my_mcp_server:app", "--host", "0.0.0.0", "--port", "8080"]
