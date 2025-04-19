# MCP Quickstart

Step 1 - Build Docker

```
docker-compose build
```


Step 2 - Run Docker

```
docker-compose up
```

Claude Desktop connects to ```localhost:8080```



# Connecting Claude Desktop

## Install Astral

Astral is a package manager for Python

```
curl -Ls https://astral.sh/uv/install.sh | sh
```

Confirm Astral is installed

```
ls ~/.local/bin/uvx
```


### Update Env Variables

```
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```


Unfortunately, Claues cannot find uvx in its environemnt. Claude was launched from the macOS GUI which doesnt load ```~/.zshrc```

The solution is to help Claude Desktop find uvx globally when the launched from the Dock or Spotlight.

```
launchctl setenv PATH "$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
```


## Add 

Craete ```~/bin/mcp-server-sqlite``` 

```
#!/bin/bash

DB_URL="http://localhost:8080/mcp"

while IFS= read -r line; do
  if [[ -z "$line" ]]; then
    continue
  fi

  # Sanity: validate JSON input is MCP-ish
  if ! echo "$line" | grep -q '"jsonrpc": *"2.0"'; then
    echo '{"jsonrpc":"2.0","id":null,"error":{"code":-32600,"message":"Invalid Request"}}'
    continue
  fi

  # Forward to FastAPI server
  response=$(curl -s -X POST "$DB_URL" \
    -H "Content-Type: application/json" \
    -d "$line")

  echo "$response"
done
```

Set Permissions
```
chmod +x ~/bin/mcp-server-sqlite
```


## Configure Clade

Create ```~/Library/Application\ Support/Claude/claude_desktop_config.json``` and add this

```
{
  "mcpServers": {
    "sqlite": {
      "command": "uvx",
      "args": ["mcp-server-sqlite", "--db-path", "/Users/YOUR_USERNAME/path/to/mcp_quickstart/data/test.db"]
    }
  }
}
````


Verify your work by simulating Claude

```
 uvx mcp-server-sqlite --db-path /Users/YOUR_USERNAME/path/to/mcp_quickstart/data/test.db
```




# Troubleshooting

## Check SQL

```
 docker exec -it $(docker ps --filter "name=mcp-server" -q) sqlite3 /data/test.db
```

## Docker Cache

stop & remove containers + volumes
rebuild fresh
run docker
```
docker-compose down -v && docker-compose build && docker-compose up
```


# Resources

https://www.claudemcp.com/docs/quickstart



