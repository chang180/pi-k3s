# Stage 1: Build frontend assets
FROM node:20-alpine AS frontend-builder

WORKDIR /app

# Install PHP 8.4 + extensions (required by Laravel 12 and Wayfinder Vite plugin)
RUN apk add --no-cache \
    php84 \
    php84-phar \
    php84-iconv \
    php84-openssl \
    php84-tokenizer \
    php84-fileinfo \
    php84-mbstring \
    php84-dom \
    php84-xml \
    php84-session \
    php84-pdo \
    php84-pdo_sqlite \
    php84-sqlite3 \
    php84-bcmath \
    php84-curl \
    php84-ctype \
    && ln -sf /usr/bin/php84 /usr/bin/php

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Copy application files for Wayfinder
COPY . .

# Copy package files
COPY package.json package-lock.json ./

# Install composer dependencies (needed for artisan commands)
RUN composer install --no-dev --no-interaction --optimize-autoloader --ignore-platform-reqs

# Install npm dependencies (CI mode + timeout 避免在 Docker 內卡住或無輸出)
ENV CI=1
ENV npm_config_fetch_timeout=300000
ENV npm_config_fetch_retries=5
RUN npm ci

# Build frontend assets (Wayfinder will now work)
RUN npm run build

# Stage 2: PHP Runtime (optimized for 1C1G VPS)
FROM php:8.4-fpm-alpine

# Install only necessary system dependencies and PHP extensions (SQLite-only, no MySQL/PostgreSQL)
RUN apk add --no-cache \
    nginx \
    supervisor \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    oniguruma-dev \
    sqlite-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo_sqlite \
        gd \
        zip \
        bcmath \
        opcache \
        pcntl \
    && rm -rf /var/cache/apk/*

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copy application files
COPY . .

# Copy built frontend assets from previous stage
COPY --from=frontend-builder /app/public/build ./public/build

# Create .env from example if needed (will be overridden by container env vars)
RUN cp .env.example .env || true

# Install PHP dependencies (production only)
# --ignore-platform-reqs: avoid build/runtime PHP version mismatch in CI or cross-platform builds
RUN composer install --no-dev --no-interaction --optimize-autoloader --no-scripts --ignore-platform-reqs

# Create SQLite database directory and file
RUN mkdir -p /var/www/html/database \
    && touch /var/www/html/database/database.sqlite \
    && chown -R www-data:www-data /var/www/html/database

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html/storage \
    && chmod -R 755 /var/www/html/bootstrap/cache

# Copy nginx configuration
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/default.conf /etc/nginx/http.d/default.conf

# Copy supervisor configuration
COPY docker/supervisord.conf /etc/supervisord.conf

# PHP configuration (optimized for 1C1G VPS)
RUN echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.memory_consumption=48" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.interned_strings_buffer=4" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.max_accelerated_files=3000" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.validate_timestamps=0" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "memory_limit=64M" >> /usr/local/etc/php/conf.d/memory.ini \
    && echo "realpath_cache_size=512K" >> /usr/local/etc/php/conf.d/memory.ini \
    && echo "realpath_cache_ttl=600" >> /usr/local/etc/php/conf.d/memory.ini

# PHP-FPM pool configuration (low memory: static pool with limited workers)
COPY docker/php-fpm-pool.conf /usr/local/etc/php-fpm.d/www.conf

# Create entrypoint script
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
