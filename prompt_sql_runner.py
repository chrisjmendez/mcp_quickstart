from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
import subprocess
import requests
import json

app = FastAPI()

# Allow browser requests
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 🧬 Define your database schema for LLaMA's brain
DB_SCHEMA = """
Table: products
Columns:
  - id: integer, primary key
  - name: text
  - price: real
"""

# 🧠 Ask LLaMA to turn English into SQL
def prompt_llama_for_sql(user_question):
    system_prompt = f"You are an AI that converts natural language to SQL for this SQLite schema:\n{DB_SCHEMA}\n\nQuestion: {user_question}\nSQL:"

    result = subprocess.run(
        ["ollama", "run", "codellama:instruct"],
        input=system_prompt,
        text=True,
        capture_output=True
    )

    output = result.stdout.strip()

    # 🧼 Find best SELECT line
    sql_lines = [line for line in output.splitlines() if line.strip().lower().startswith("select")]
    if sql_lines:
        return sql_lines[0], "Model-generated SQL"
    else:
        return "SELECT * FROM products LIMIT 5;", "Model hallucinated, used fallback."

# 🚀 Query the MCP server
def run_sql_on_local_mcp(sql):
    payload = {
        "jsonrpc": "2.0",
        "id": "web-client",
        "method": "query",
        "params": { "sql": sql }
    }

    try:
        response = requests.post("http://localhost:8080/mcp", json=payload)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        return {"error": str(e)}

# 📦 For handling input from frontend
class UserQuestion(BaseModel):
    question: str

# 🎨 Serve the HTML UI
@app.get("/", response_class=HTMLResponse)
async def serve_ui():
    return """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Ask Your Database</title>
      <meta charset="UTF-8" />
      <style>
        body { font-family: sans-serif; max-width: 700px; margin: 40px auto; padding: 20px; }
        textarea { width: 100%; height: 100px; font-family: monospace; font-size: 14px; }
        button { padding: 10px 20px; font-size: 16px; margin-top: 10px; }
        pre { background: #f6f6f6; padding: 15px; border: 1px solid #ddd; overflow-x: auto; }
      </style>
    </head>
    <body>
      <h1>📊 Ask Your Database (via LLaMA)</h1>

      <label>Your question:</label>
      <textarea id="question" placeholder="e.g. What are the top 5 most expensive products?"></textarea>
      <button onclick="askDatabase()">Ask</button>

      <h2>🎯 Result</h2>
      <pre id="output">(waiting for input)</pre>

      <script>
        async function askDatabase() {
          const userInput = document.getElementById("question").value;

          // First: ask LLaMA
          const llamaResp = await fetch("/run_llama", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ question: userInput })
          });

          const llamaData = await llamaResp.json();
          const sql = llamaData.sql || "SELECT * FROM products LIMIT 5;";
          const note = llamaData.note || "";

          // Show generated SQL
          document.getElementById("output").textContent = `-- SQL -->\\n${sql}\\n\\n${note}\\n\\n(loading...)`;

          // Then: run it through MCP
          const mcpPayload = {
            jsonrpc: "2.0",
            id: "web-client",
            method: "query",
            params: { sql }
          };

          try {
            const mcpResp = await fetch("http://localhost:8080/mcp", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify(mcpPayload)
            });

            const result = await mcpResp.json();
            document.getElementById("output").textContent += "\\n\\n📊 Result:\\n" + JSON.stringify(result, null, 2);
          } catch (err) {
            document.getElementById("output").textContent += "\\n\\n❌ Error:\\n" + err;
          }
        }
      </script>
    </body>
    </html>
    """

# 🔄 Called by frontend — turns English → SQL
@app.post("/run_llama")
async def run_llama(req: UserQuestion):
    sql, note = prompt_llama_for_sql(req.question)
    return {"sql": sql, "note": note}