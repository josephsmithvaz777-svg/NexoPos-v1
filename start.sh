#!/bin/bash
set -e

echo "Configuring permissions..."
chmod -R 777 storage bootstrap/cache

echo "Running migrations and optimization..."
php artisan package:discover --ansi
php artisan storage:link
php artisan ns:translate --symlink --force
php artisan modules:symlink
php artisan migrate --force
php artisan optimize
php artisan view:cache

echo "Configuring Nginx port..."
sed -i "s/REPLACE_PORT/$PORT/g" /app/nginx.conf

echo "Starting PHP-FPM..."
php-fpm -R -y /app/php-fpm.conf -D

echo "Starting Nginx..."
nginx -c /app/nginx.conf
