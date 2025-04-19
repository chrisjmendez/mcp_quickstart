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



