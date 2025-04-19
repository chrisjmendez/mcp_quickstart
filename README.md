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

## Update Env Variables

```
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
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



