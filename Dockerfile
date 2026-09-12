# ==============================================================================
# STAGE 1: Build Frontend Assets (Node.js)
# ==============================================================================
FROM node:20-alpine AS node_builder

WORKDIR /app

# Copy package management files to leverage layer caching
COPY package*.json vite.config.js mix-manifest.json* webpack.mix.js* ./

# Install npm dependencies
RUN npm ci || npm install

# Copy application assets source files
COPY resources/ ./resources/
COPY public/ ./public/

# Build production assets (Vite or Mix automatically handled if defined in scripts)
RUN npm run build || npm run prod


# ==============================================================================
# STAGE 2: PHP Application & Production Server
# ==============================================================================
FROM php:8.2-fpm-alpine

# Install system dependencies & build tools for PHP extensions
RUN apk add --no-grad \
    bash \
    curl \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    oniguruma-dev \
    icu-dev \
    libxml2-dev \
    git \
    unzip \
    zip

# Configure and install PHP extensions required by Laravel
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        mbstring \
        exif \
        pcntl \
        bcmath \
        gd \
        zip \
        intl \
        opcache

# Copy Composer binary from official Composer image
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www

# Copy Composer configuration first for better layer caching
COPY composer.json composer.lock ./

# Install Composer dependencies (no dev packages, optimized autoloader)
RUN composer install \
    --no-dev \
    --no-interaction \
    --no-plugins \
    --no-scripts \
    --prefer-dist \
    --optimize-autoloader

# Copy the rest of the application codebase
COPY . .

# Copy compiled frontend assets from STAGE 1
COPY --from=node_builder /app/public /var/www/public

# Generate optimized Autoloader after copying source
RUN composer dump-autoload --optimize

# Set correct permissions for Laravel storage and cache directories
RUN chown -R www-data:www-data /var/www \
    && chmod -R 775 /var/www/storage /var/www/bootstrap/cache

# Expose PHP-FPM default port
EXPOSE 9000

CMD ["php-fpm"]
