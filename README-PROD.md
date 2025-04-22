
# Launching to Production

## Part 1 - Initial EC2 Setup
 
1. SSH 
```
ssh -i /path/to/your-key.pem ubuntu@your-ec2-ip
```


2. Update and Install Basics

```
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl docker.io docker-compose nginx
```

3. Enable Docker

```
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

## Part 2: Project Setup

4. Clone Repo

```
git clone https://github.com/chrisjmendez/mcp_quickstart.git
cd mcp_quickstart
```

5. Create a ```.env``` file

```
cp .env.example .env
nano .env
```

6. Set Your Domain

```
DOMAIN_URL=WWW.YOURDOMAIN.COM
```

## Part 3: Start the Services

7. Start MCP, FastAPI, and Nginx

```
docker-compose up --build -d
```

## Part 4: Add SSL with Certbot

8. Generate certificates

```
docker run -it --rm \
  -v "$(pwd)/certbot/www:/var/www/certbot" \
  -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
  certbot/certbot certonly \
  --webroot -w /var/www/certbot \
  --email YOUR_EMAIL@EMAIL.COM \
  --agree-tos \
  --no-eff-email \
  -d WWW.YOURDOMAIN.COM 
```

9. Reload Nginx

```
docker-compose restart nginx
```

10. Add SSL Renewal

```
0 0 * * * docker run --rm \
  -v "$(pwd)/certbot/www:/var/www/certbot" \
  -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
  certbot/certbot renew \
  --webroot -w /var/www/certbot && docker-compose reload nginx
```

Copy this Nginx file to main nginx
```
mv nginx/conf/default.conf nginx/conf/default.conf.template
```