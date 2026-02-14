#!/bin/sh

set -e

# Create necessary directories (storage may be an empty volume mount)
mkdir -p /var/log/supervisor /var/log/nginx
mkdir -p /var/www/html/storage/app/public
mkdir -p /var/www/html/storage/framework/cache/data
mkdir -p /var/www/html/storage/framework/sessions
mkdir -p /var/www/html/storage/framework/views
mkdir -p /var/www/html/storage/logs
mkdir -p /var/www/html/bootstrap/cache

# Set proper permissions
chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

# Auto-detect SSL: if Let's Encrypt certs are mounted, use SSL nginx config
if [ -f /etc/letsencrypt/live/*/fullchain.pem ] 2>/dev/null; then
    echo "SSL certificates detected, enabling HTTPS..."
    cp /etc/nginx/http.d/default-ssl.conf /etc/nginx/http.d/default.conf
fi

# Run Laravel optimizations
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Run migrations if AUTO_MIGRATE is set
if [ "$AUTO_MIGRATE" = "true" ]; then
    echo "Running migrations..."
    php artisan migrate --force --no-interaction
fi

# Execute CMD
exec "$@"
