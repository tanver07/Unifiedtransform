# ==============================================================================
# STAGE 1: Build Frontend Assets
# ==============================================================================
FROM node:20-alpine AS node_builder

WORKDIR /app

COPY package*.json vite.config.js* mix-manifest.json* webpack.mix.js* ./
RUN npm ci || npm install

COPY resources/ ./resources/
COPY public/ ./public/
RUN npm run build || npm run prod


# ==============================================================================
# STAGE 2: Web Server (Nginx + PHP 8.2)
# ==============================================================================
FROM richarvey/nginx-php-fpm:latest

# Environment config for Nginx-PHP image
ENV WEBROOT="/var/www/html/public"
ENV PHP_ERRORS_STDERR="1"
ENV RUN_CLI="false"
ENV REAL_IP_HEADER="1"

WORKDIR /var/www/html

# Copy application files
COPY . .

# Copy compiled frontend assets from STAGE 1
COPY --from=node_builder /app/public /var/www/html/public

# Install Composer dependencies
RUN composer install \
    --no-dev \
    --no-interaction \
    --no-plugins \
    --no-scripts \
    --prefer-dist \
    --optimize-autoloader

# Generate optimized Autoloader
RUN composer dump-autoload --optimize --no-scripts

# Set permissions for storage and cache
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Expose HTTP port for Render health checks
EXPOSE 80

CMD ["/start.sh"]
