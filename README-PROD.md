

Run this from your terminal after Docker Compose is up:

```
docker-compose run --rm certbot certonly \
  --webroot \
  --webroot-path=/var/www/certbot \
  --email you@example.com \
  --agree-tos \
  --no-eff-email \
  -d YOUR_DOMAIN.com
```


Copy this Nginx file to main nginx
```
mv nginx/conf/default.conf nginx/conf/default.conf.template
```