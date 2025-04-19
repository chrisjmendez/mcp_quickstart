# my_mcp_server.py
from fastapi import FastAPI
import sqlite3

app = FastAPI()

@app.get("/")
def root():
    return {"message": "MCP SQLite Server is alive"}

@app.get("/products")
def get_products():
    conn = sqlite3.connect("~/test.db")
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM products")
    rows = cursor.fetchall()
    conn.close()
    return {"products": rows}
