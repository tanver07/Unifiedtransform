FROM php:7.4-apache

# Set working directory
WORKDIR /var/www

# Fix EOL Debian repositories for PHP 7.4 (Buster)
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i 's/security.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i '/stretch-updates/d' /etc/apt/sources.list && \
    sed -i '/buster-updates/d' /etc/apt/sources.list

# Install system dependencies
RUN apt-get update -o Acquire::Check-Valid-Until=false --fix-missing && apt-get install -y \
    build-essential \
    libzip-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libxml2-dev \
    wget \
    zip \
    unzip \
    git \
    curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PHP extensions required by Laravel/Unifiedtransform
RUN docker-php-ext-install pdo_mysql zip exif pcntl
RUN docker-php-ext-install gd && docker-php-ext-enable gd

# Enable Apache mod_rewrite for Laravel routing
RUN a2enmod rewrite

# Configure Apache to serve from Laravel's /public folder
ENV APACHE_DOCUMENT_ROOT /var/www/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/conf-available/*.conf

# Install Composer
COPY --from=composer:2.2 /usr/bin/composer /usr/bin/composer

# Copy application files into container
COPY . /var/www

# Install Laravel dependencies
RUN composer install --no-dev --optimize-autoloader

# Create necessary storage directories
RUN mkdir -p /var/www/storage/app/purify

# Set file permissions for web server
RUN chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache

# Expose HTTP port
EXPOSE 80

CMD ["apache2-foreground"]
