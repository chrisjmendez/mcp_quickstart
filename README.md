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



