#!/usr/bin/env bash
set -e

DOMAIN="$1"
if [ -z "$DOMAIN" ]; then
  echo "Usage: ./add-domain.sh domain.com"
  exit 1
fi

sudo mkdir -p /var/www/$DOMAIN/public
sudo chown -R $USER:www-data /var/www/$DOMAIN
echo "<h1>$DOMAIN aktif</h1>" | sudo tee /var/www/$DOMAIN/public/index.html >/dev/null

sudo tee /etc/nginx/sites-available/$DOMAIN >/dev/null <<EOF_NGX
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;

    root /var/www/$DOMAIN/public;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    }
}
EOF_NGX

sudo ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/ || true
sudo nginx -t
sudo systemctl reload nginx

echo "Domain $DOMAIN sudah ditambahkan. Lanjutkan set DNS dan SSL certbot."
