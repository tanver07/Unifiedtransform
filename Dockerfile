FROM node:20-alpine AS node_builder

WORKDIR /app

# Copy dependency files and install
COPY package*.json ./
RUN npm ci

# Copy full application code and build assets
COPY . .
RUN npm run build || npm run prod

FROM php:8.2-fpm

# Install required system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    zip \
    unzip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install required PHP extensions for Laravel
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip

# Copy official Composer binary
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www

# Copy application source code
COPY . /var/www

# Copy built frontend assets from Stage 1
COPY --from=node_builder /app/public/build /var/www/public/build

# ---------------------------------------------------------------------
# COMPOSER FIX: Install without scripts to prevent Auth::routes error
# ---------------------------------------------------------------------
RUN composer install --no-dev --optimize-autoloader --ignore-platform-reqs --no-scripts
RUN composer dump-autoload --optimize
# ---------------------------------------------------------------------

# Set proper permissions for storage and cache directories
RUN chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache \
    && chmod -R 775 /var/www/storage /var/www/bootstrap/cache

EXPOSE 9000

CMD ["php-fpm"]
