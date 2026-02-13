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

# Install npm dependencies
RUN npm ci

# Build frontend assets (Wayfinder will now work)
RUN npm run build

# Stage 2: PHP Runtime
FROM php:8.4-fpm-alpine

# Install system dependencies and PHP extensions
RUN apk add --no-cache \
    nginx \
    supervisor \
    mysql-client \
    postgresql-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    oniguruma-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        pdo_pgsql \
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

# Create .env from example if needed (will be overridden by K8s env vars)
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

# PHP-FPM configuration
RUN echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.memory_consumption=128" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.interned_strings_buffer=8" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.max_accelerated_files=10000" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.validate_timestamps=0" >> /usr/local/etc/php/conf.d/opcache.ini

# Create entrypoint script
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
