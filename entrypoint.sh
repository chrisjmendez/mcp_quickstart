#!/bin/bash

DB_PATH="/data/test.db"

echo "📁 Checking database at $DB_PATH..."

# Create /data if it doesn't exist
mkdir -p /data

# If DB doesn't exist, create it
if [ ! -f "$DB_PATH" ]; then
  echo "🛠️ Creating new database at $DB_PATH..."

  sqlite3 "$DB_PATH" <<EOF
-- Products table
CREATE TABLE products (
  id INTEGER PRIMARY KEY,
  name TEXT,
  price REAL
);

INSERT INTO products (name, price) VALUES
  ('Widget', 19.99),
  ('Gadget', 29.99),
  ('Gizmo', 39.99),
  ('Smart Watch', 199.99),
  ('Wireless Earbuds', 89.99),
  ('Portable Charger', 24.99),
  ('Bluetooth Speaker', 79.99),
  ('Phone Stand', 15.99),
  ('Laptop Sleeve', 34.99),
  ('Mini Drone', 299.99),
  ('LED Desk Lamp', 45.99),
  ('Keyboard', 129.99),
  ('Mouse Pad', 12.99),
  ('USB Hub', 49.99),
  ('Webcam', 69.99),
  ('Screen Protector', 9.99),
  ('Travel Adapter', 27.99),
  ('Gaming Headset', 159.99),
  ('Fitness Tracker', 119.99),
  ('Portable SSD', 179.99);

-- Metadata table (required by Claude)
CREATE TABLE metadata (
  key TEXT PRIMARY KEY,
  value TEXT
);

INSERT INTO metadata (key, value) VALUES
  ('title', 'Product Database'),
  ('description', 'A sample database of tech products.'),
  ('version', '1.0');

-- Documents table (expected by Claude MCP)
CREATE TABLE documents (
  id INTEGER PRIMARY KEY,
  name TEXT,
  content TEXT
);

INSERT INTO documents (name, content) VALUES
  ('welcome', 'Hello Claude, welcome to the database.'),
  ('about', 'This is a product and metadata SQLite dataset used for testing Claude MCP queries.');
EOF

  echo "✅ Database created and initialized."
else
  echo "✅ Existing database found. Verifying tables..."

  # Sanity check for metadata table
  if ! sqlite3 "$DB_PATH" "SELECT 1 FROM metadata LIMIT 1;" 2>/dev/null; then
    echo "⚠️ Metadata table missing. Re-creating..."

    sqlite3 "$DB_PATH" <<EOF
CREATE TABLE IF NOT EXISTS metadata (
  key TEXT PRIMARY KEY,
  value TEXT
);

INSERT OR REPLACE INTO metadata (key, value) VALUES
  ('title', 'Product Database'),
  ('description', 'A sample database of tech products.'),
  ('version', '1.0');
EOF
  fi

  # Sanity check for documents table
  if ! sqlite3 "$DB_PATH" "SELECT 1 FROM documents LIMIT 1;" 2>/dev/null; then
    echo "⚠️ Documents table missing. Re-creating..."

    sqlite3 "$DB_PATH" <<EOF
CREATE TABLE IF NOT EXISTS documents (
  id INTEGER PRIMARY KEY,
  name TEXT,
  content TEXT
);

INSERT INTO documents (name, content) VALUES
  ('welcome', 'Hello Claude, welcome to the database.'),
  ('about', 'This is a product and metadata SQLite dataset used for testing Claude MCP queries.');
EOF
  fi
fi

echo "🚀 Starting MCP server..."
exec uvicorn my_mcp_server:app --host 0.0.0.0 --port 8080