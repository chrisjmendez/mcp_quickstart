from fastapi import FastAPI
from fastapi import WebSocket, WebSocketDisconnect
from pydantic import BaseModel
import sqlite3

app = FastAPI()

DB_PATH = "/data/test.db"  # Full path inside the Docker container

# Home route
@app.get("/")
def root():
    return {"message": "MCP SQLite Server is alive"}

# Static GET route: all products
@app.get("/products")
def get_products():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM products")
    rows = cursor.fetchall()
    conn.close()
    return {"products": rows}

# Schema for MCP-style POST query
class MCPRequest(BaseModel):
    query: str

# Dynamic SQL query via MCP
@app.post("/mcp")
def mcp_query(req: MCPRequest):
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute(req.query)
        rows = cursor.fetchall()
        columns = [desc[0] for desc in cursor.description] if cursor.description else []
        conn.close()
        return {"columns": columns, "rows": rows}
    except Exception as e:
        return {"error": str(e)}

@app.websocket("/ws/mcp")
async def websocket_mcp(websocket: WebSocket):
    await websocket.accept()
    await websocket.send_text("🟢 Connected to MCP SQLite WebSocket.")

    try:
        while True:
            query = await websocket.receive_text()
            try:
                conn = sqlite3.connect(DB_PATH)
                cursor = conn.cursor()
                cursor.execute(query)
                rows = cursor.fetchall()
                columns = [desc[0] for desc in cursor.description] if cursor.description else []
                conn.close()
                await websocket.send_json({
                    "columns": columns,
                    "rows": rows
                })
            except Exception as e:
                await websocket.send_json({
                    "error": str(e)
                })

    except WebSocketDisconnect:
        print("🔌 WebSocket disconnected")
