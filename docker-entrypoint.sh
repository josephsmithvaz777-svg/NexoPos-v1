#!/bin/bash
set -e

# Esperar a que la base de datos esté lista (opcional, pero recomendado si están en el mismo stack)
# /usr/bin/wait-for-it.sh db:3306 -t 60

# Ejecutar migraciones
echo "Running migrations..."
php artisan migrate --force

# Cachear configuración y rutas
echo "Caching configuration..."
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache

# Crear enlace simbólico de almacenamiento
php artisan storage:link

# Ejecutar comando pasado al contenedor (normalmente apache2-foreground)
exec "$@"
