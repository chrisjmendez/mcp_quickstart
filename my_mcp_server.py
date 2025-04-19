from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
import sqlite3

app = FastAPI()

DB_PATH = "/data/test.db"

@app.get("/")
def root():
    return {"message": "MCP SQLite Server is alive"}

@app.get("/products")
def get_products():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM products")
    rows = cursor.fetchall()
    conn.close()
    return {"products": rows}

@app.post("/mcp")
async def mcp_handler(request: Request):
    data = await request.json()
    query_id = data.get("id")
    method = data.get("method")
    params = data.get("params", {})
    sql = params.get("sql")

    if method != "query" or not sql:
        return JSONResponse(
            status_code=400,
            content={
                "jsonrpc": "2.0",
                "id": query_id,
                "error": {
                    "code": -32600,
                    "message": "Invalid Request"
                }
            }
        )

    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute(sql)
        rows = cursor.fetchall()
        columns = [desc[0] for desc in cursor.description]
        conn.close()

        return {
            "jsonrpc": "2.0",
            "id": query_id,
            "result": {
                "columns": columns,
                "rows": rows
            }
        }

    except Exception as e:
        return {
            "jsonrpc": "2.0",
            "id": query_id,
            "error": {
                "code": -32000,
                "message": str(e)
            }
        }