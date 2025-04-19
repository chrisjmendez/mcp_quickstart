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

## Docker Cache

```
docker-compose down -v  # stop & remove containers + volumes
docker-compose build    # rebuild fresh
docker-compose up       # relaunch
```


# Resources

https://www.claudemcp.com/docs/quickstart



