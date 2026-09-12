FROM php:8.1-apache

# Set working directory
WORKDIR /var/www

# Install system dependencies
RUN apt-get update && apt-get install -y \
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
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy application files into container
COPY . /var/www

# Install Laravel dependencies
RUN composer install --no-dev --optimize-autoloader --ignore-platform-reqs

# Create necessary storage directories
RUN mkdir -p /var/www/storage/app/purify

# Set file permissions for web server
RUN chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache

# Expose HTTP port
EXPOSE 80

CMD ["apache2-foreground"]
