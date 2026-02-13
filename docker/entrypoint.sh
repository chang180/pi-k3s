#!/bin/sh

set -e

# Create necessary directories
mkdir -p /var/log/supervisor /var/log/nginx

# Set proper permissions
chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

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
