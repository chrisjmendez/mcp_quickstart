from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
import requests
import json
import os

app = FastAPI()

# Allow all origins for demo purposes — you can lock this down in production
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Define your database schema so the AI knows what it's working with
DB_SCHEMA = """
Table: products
Columns:
  - id: integer, primary key
  - name: text
  - price: real
"""

# Use env variable to access Ollama running on the Docker host
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://host.docker.internal:11434")

def prompt_llama_for_sql(user_question):
    system_prompt = f"You are an AI that converts natural language to SQL for this SQLite schema:\n{DB_SCHEMA}\n\nQuestion: {user_question}\nSQL:"

    payload = {
        "model": "codellama:instruct",
        "prompt": system_prompt,
        "stream": False
    }

    try:
        res = requests.post(f"{OLLAMA_URL}/api/generate", json=payload)
        res.raise_for_status()
        response = res.json()
        output = response.get("response", "")
        sql_lines = [line for line in output.splitlines() if "select" in line.lower()]
        return sql_lines[0] if sql_lines else "SELECT * FROM products LIMIT 5;", output
    except Exception as e:
        return "SELECT * FROM products LIMIT 5;", f"-- Error from LLaMA: {e}"

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
        response = requests.post("http://mcp-server:8080/mcp", json=mcp_payload)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        return {"error": str(e)}

class UserQuestion(BaseModel):
    question: str

@app.get("/", response_class=HTMLResponse)
async def serve_ui():
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Ask LLaMA</title>
        <style>
            body { font-family: sans-serif; max-width: 700px; margin: 2em auto; padding: 1em; }
            textarea { width: 100%; height: 100px; font-size: 1em; }
            pre { background: #f6f6f6; padding: 1em; border: 1px solid #ccc; white-space: pre-wrap; }
        </style>
    </head>
    <body>
        <h1>🤖 Ask your database anything</h1>
        <textarea id="question" placeholder="E.g. What are the top 5 most expensive items?"></textarea><br>
        <button onclick="ask()">Ask</button>
        <h3>🔍 SQL Generated:</h3>
        <pre id="sql">...</pre>
        <h3>📊 Query Result:</h3>
        <pre id="result">...</pre>

        <script>
        async function ask() {
            const question = document.getElementById("question").value;
            const res = await fetch("/run_llama", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ question })
            });
            const data = await res.json();
            document.getElementById("sql").innerText = data.sql;

            const mcpPayload = {
                jsonrpc: "2.0",
                id: "web-client",
                method: "query",
                params: { sql: data.sql }
            };

            const mcpRes = await fetch("http://localhost:8080/mcp", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify(mcpPayload)
            });

            const result = await mcpRes.json();
            document.getElementById("result").innerText = JSON.stringify(result, null, 2);
        }
        </script>
    </body>
    </html>
    """

@app.post("/run_llama")
async def run_llama(req: UserQuestion):
    sql, note = prompt_llama_for_sql(req.question)
    return {"sql": sql, "note": note}