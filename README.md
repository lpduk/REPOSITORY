# Panduan Setup VPS BiznetGio Menjadi Webserver Multi-Domain

Panduan ini ditujukan untuk VPS dengan spek seperti berikut:

- Provider: BiznetGio
- Paket: NeoLite SS 2.2
- OS: Ubuntu 24.04
- Contoh user SSH: `quinfarraz`
- Contoh IP publik: `103.127.99.227`

## 1) Login ke VPS

```bash
ssh quinfarraz@103.127.99.227
```

## 2) Update sistem dan instal paket webserver

```bash
sudo apt update && sudo apt upgrade -y
sudo timedatectl set-timezone Asia/Jakarta

sudo apt install -y nginx mariadb-server \
php-fpm php-mysql php-cli php-curl php-mbstring php-xml php-zip \
ufw fail2ban certbot python3-certbot-nginx

sudo systemctl enable nginx mariadb
sudo systemctl start nginx mariadb
```

## 3) Konfigurasi firewall dasar

```bash
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable
sudo ufw status
```

## 4) Struktur direktori multi-domain

Gunakan pola direktori berikut untuk setiap domain:

```text
/var/www/<nama-domain>/public
```

Contoh:

```bash
sudo mkdir -p /var/www/quinfarraz.net/public
sudo chown -R $USER:www-data /var/www/quinfarraz.net
sudo chmod -R 755 /var/www/quinfarraz.net
```

## 5) Buat konten awal

```bash
cat > /var/www/quinfarraz.net/public/index.php << 'EOF_PHP'
<?php
echo "Website quinfarraz.net aktif. Host: " . $_SERVER['HTTP_HOST'];
EOF_PHP
```

## 6) Konfigurasi Nginx per domain

Buat file:

```bash
sudo nano /etc/nginx/sites-available/quinfarraz.net
```

Isi konfigurasi:

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name quinfarraz.net www.quinfarraz.net;

    root /var/www/quinfarraz.net/public;
    index index.php index.html;

    access_log /var/log/nginx/quinfarraz.net.access.log;
    error_log  /var/log/nginx/quinfarraz.net.error.log;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
```

Aktifkan konfigurasi:

```bash
sudo ln -s /etc/nginx/sites-available/quinfarraz.net /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## 7) Konfigurasi DNS domain

Pada DNS manager domain, buat record:

- `A` untuk `@` -> `103.127.99.227`
- `A` untuk `www` -> `103.127.99.227`

## 8) Pasang SSL per domain (Let's Encrypt)

```bash
sudo certbot --nginx -d quinfarraz.net -d www.quinfarraz.net
sudo certbot renew --dry-run
```

## 9) Menambah domain baru

Misal domain baru `contohdomain.com`:

1. Buat direktori:

```bash
sudo mkdir -p /var/www/contohdomain.com/public
sudo chown -R $USER:www-data /var/www/contohdomain.com
echo "<h1>contohdomain.com aktif</h1>" | sudo tee /var/www/contohdomain.com/public/index.html
```

2. Buat vhost baru di `/etc/nginx/sites-available/contohdomain.com` (isi sama, ganti domain dan root).
3. Aktifkan site:

```bash
sudo ln -s /etc/nginx/sites-available/contohdomain.com /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

4. Tambahkan DNS `A` (`@` dan `www`) ke IP VPS.
5. Pasang SSL:

```bash
sudo certbot --nginx -d contohdomain.com -d www.contohdomain.com
```

## 10) Script helper tambah domain

Simpan sebagai `scripts/add-domain.sh`:

```bash
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
```

## 11) Catatan praktik baik

- Gunakan SSH key (hindari login password jika memungkinkan).
- Rutin backup `/var/www` dan database.
- Pantau resource (`htop`, `free -h`, `df -h`).
- Untuk beban tinggi, aktifkan caching dan optimasi PHP-FPM.

