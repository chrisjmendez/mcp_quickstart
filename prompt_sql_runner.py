import json
import requests
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel

app = FastAPI()

# Enable CORS for frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For dev only
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Your database schema to help LLaMA understand context
DB_SCHEMA = """
Table: products
Columns:
  - id: integer, primary key
  - name: text
  - price: real
"""

# Use Ollama's HTTP API instead of subprocess
def prompt_llama_for_sql(question):
    prompt = f"You are an AI that converts natural language to SQL for this SQLite schema:\n{DB_SCHEMA}\n\nQuestion: {question}\nSQL:"
    try:
        response = requests.post(
            "http://localhost:11434/api/generate",
            json={"model": "codellama:instruct", "prompt": prompt, "stream": False},
            timeout=30
        )
        response.raise_for_status()
        output = response.json().get("response", "").strip()

        # Grab the first line that looks like SQL
        for line in output.splitlines():
            if line.strip().lower().startswith("select"):
                return line.strip(), "✅ success"

        return "SELECT * FROM products LIMIT 5;", "⚠️ fallback to default"
    except Exception as e:
        return "SELECT * FROM products LIMIT 5;", f"❌ Error: {str(e)}"

# Forward SQL to MCP server
def run_sql_on_local_mcp(sql):
    mcp_payload = {
        "jsonrpc": "2.0",
        "id": "web-client",
        "method": "query",
        "params": {
            "sql": sql
        }
    }
    try:
        response = requests.post("http://localhost:8080/mcp", json=mcp_payload)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        return {"error": str(e)}

# Frontend input
class UserQuestion(BaseModel):
    question: str

# Serve HTML UI
@app.get("/", response_class=HTMLResponse)
async def serve_ui():
    return """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Ask Your DB</title>
      <meta charset="UTF-8" />
      <style>
        body { font-family: sans-serif; max-width: 700px; margin: 2rem auto; }
        textarea, pre { width: 100%; font-family: monospace; font-size: 1rem; }
        textarea { height: 100px; }
        button { margin: 10px 0; font-size: 1rem; }
      </style>
    </head>
    <body>
      <h1>🧠 Ask Your Database</h1>
      <textarea id="question" placeholder="e.g. What are the top 5 most expensive items?"></textarea><br/>
      <button onclick="ask()">Ask</button>
      <h2>🔎 SQL:</h2>
      <pre id="sql">(waiting)</pre>
      <h2>📊 Result:</h2>
      <pre id="result">(waiting)</pre>
      <script>
        async function ask() {
          const q = document.getElementById("question").value;
          const res = await fetch("/run_llama", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ question: q })
          });
          const { sql, note } = await res.json();
          document.getElementById("sql").textContent = sql + "  // " + note;

          const result = await fetch("http://localhost:8080/mcp", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              jsonrpc: "2.0",
              id: "web-client",
              method: "query",
              params: { sql }
            })
          }).then(res => res.json());

          document.getElementById("result").textContent = JSON.stringify(result, null, 2);
        }
      </script>
    </body>
    </html>
    """

# Route that hits LLaMA
@app.post("/run_llama")
async def run_llama(req: UserQuestion):
    sql, note = prompt_llama_for_sql(req.question)
    return {"sql": sql, "note": note}